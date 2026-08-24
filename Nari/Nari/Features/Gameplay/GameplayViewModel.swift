import AVFoundation
import CoreGraphics
import Foundation
import Observation
import OSLog

/// Runs a play session end to end: the placement tutorial, the calibration hold,
/// the countdown, and then the scored loop.
///
/// This is the one state machine the design asks for. The loop's own rules live
/// in `RunEngine` and the body reading lives in `MotionTracker`; this type owns
/// the phase, wires those two together frame by frame, and turns what came back
/// into sound and screen state.
@MainActor
@Observable
final class GameplayViewModel {

    enum Phase: Equatable {
        /// Sketchbook instructions for putting the iPad down and stepping back.
        case tutorial
        /// Camera is being switched on.
        case preparing
        /// Waiting for the whole body to stay in frame long enough.
        case calibrating
        /// The green room: track name and a countdown into the run.
        case starting(remaining: Double)
        case playing
        case paused
        case gameOver
        case unavailable(Problem)

        enum Problem: Equatable {
            case permissionDenied
            case noCamera
        }
    }

    /// How long the whole body has to stay in frame before the countdown starts.
    static let calibrationSeconds: Double = 3
    /// The green room countdown.
    static let countdownSeconds: Double = 3
    /// Losing the body for this long during play sends the player back to
    /// calibration rather than leaving the markers frozen on screen.
    private static let bodyLostGraceSeconds: Double = 2

    private(set) var phase: Phase = .tutorial
    private(set) var calibrationProgress: Double = 0
    private(set) var isBodyVisible = false
    private(set) var imageSize: CGSize = .zero

    /// The loop. Rebuilt on retry so a new run starts from a clean Taksu meter.
    private(set) var run = RunEngine()
    private(set) var tracker = MotionTracker()

    /// The most recent event worth flashing on screen, and when it landed. The
    /// view fades it out on its own rather than the model running a timer.
    private(set) var lastEvent: RunEvent?
    private(set) var lastEventAt: Date = .distantPast

    @ObservationIgnored private let poses: PoseProviding
    @ObservationIgnored private let source: BodyPoseSource
    @ObservationIgnored private let settings: SettingsService
    @ObservationIgnored private let rules: RunRules = .default
    @ObservationIgnored private let audio: AudioServicing
    @ObservationIgnored private let scores: ScoreHistoryStoring
    @ObservationIgnored private let gameCenter: LeaderboardProviding
    @ObservationIgnored private let onExit: () -> Void
    @ObservationIgnored private var consumer: Task<Void, Never>?
    @ObservationIgnored private var lastTimestamp: TimeInterval?
    @ObservationIgnored private var bodyLostSeconds: Double = 0
    @ObservationIgnored private var lastPoseLog: TimeInterval = 0

    init(
        poses: PoseProviding,
        source: BodyPoseSource,
        audio: AudioServicing,
        scores: ScoreHistoryStoring,
        gameCenter: LeaderboardProviding,
        settings: SettingsService,
        onExit: @escaping () -> Void
    ) {
        self.poses = poses
        self.source = source
        self.audio = audio
        self.scores = scores
        self.gameCenter = gameCenter
        self.settings = settings
        self.onExit = onExit
    }

    deinit {
        consumer?.cancel()
        source.stop()
    }

    var captureSession: AVCaptureSession? { source.captureSession }

    func attachPreview(_ layer: AVCaptureVideoPreviewLayer) {
        source.attachPreview(layer)
    }

    /// The preview is mirrored so the player sees themselves the way a mirror
    /// would show them; marker positions have to be flipped to match.
    var isPreviewMirrored: Bool { true }

    /// The pose the Freeze cue is asking for, and the card the HUD shows.
    var cuedPose: PoseDefinition? {
        run.phase.cuedSide.map { poses.pose(for: $0) }
    }

    /// True from the squat cue through to the end of its hold, so the reference
    /// card shows the nge'ed drawing instead of the ngayog one for the whole
    /// move rather than only while the player is on their way down.
    var isSquatCued: Bool {
        switch run.phase {
        case .squatCue, .squatHold: true
        default: false
        }
    }

    /// Where each coin currently sits on the camera picture.
    ///
    /// The engine keeps coins in body space so they follow the player around;
    /// this puts them back into image coordinates for the view, which is the
    /// same trip a pose marker makes.
    var coinPlacements: [CoinPlacement] {
        run.coinField.coins.map { coin in
            CoinPlacement(
                id: coin.id,
                value: coin.value,
                center: coin.position,
                radius: coin.radius,
                remainingFraction: coin.remainingFraction
            )
        }
    }

    /// Sparks still burning where feet have landed, newest last.
    private(set) var footSparks: [FootSpark] = []

    var clockText: String { RunClock.text(for: run.elapsed) }

    // MARK: - Camera framing

    /// Whether this device can offer a wider view than the standard crop. False
    /// on the simulator and on any camera with nothing left to widen into, so
    /// the control can stay off screen rather than lie.
    var canChangeFieldOfView: Bool { source.supportsFieldOfViewChange }

    var fieldOfView: CameraFieldOfView { settings.settings.cameraFieldOfView }

    /// Swapping framing mid-calibration changes how much of the player is in
    /// shot, so the hold starts again rather than crediting progress made at a
    /// different zoom.
    func toggleFieldOfView() {
        audio.play(.buttonTap)
        let next = fieldOfView.toggled
        settings.setCameraFieldOfView(next)
        source.setFieldOfView(next)
        calibrationProgress = 0
    }

    // MARK: - Session control

    func startSession() async {
        guard phase == .tutorial else { return }
        phase = .preparing

        do {
            try await source.start()
            source.setFieldOfView(settings.settings.cameraFieldOfView)
        } catch BodyPoseSourceError.permissionDenied {
            phase = .unavailable(.permissionDenied)
            return
        } catch {
            phase = .unavailable(.noCamera)
            return
        }

        beginCalibration()
        consume()
    }

    func pause() {
        guard phase == .playing else { return }
        audio.play(.buttonTap)
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        // Come back through calibration so the player has time to get set again.
        beginCalibration()
    }

    /// Starts a whole new run from the game over screen.
    func retry() {
        run = RunEngine()
        tracker.reset()
        lastEvent = nil
        beginCalibration()
    }

    func exit() {
        consumer?.cancel()
        source.stop()
        onExit()
    }

    // MARK: - Frame handling

    private func beginCalibration() {
        phase = .calibrating
        calibrationProgress = 0
        bodyLostSeconds = 0
        lastTimestamp = nil
        tracker.reset()
        footSparks.removeAll()
    }

    private func consume() {
        guard consumer == nil else { return }
        consumer = Task { [weak self, source] in
            for await snapshot in source.snapshots {
                guard let self, !Task.isCancelled else { return }
                self.handle(snapshot)
            }
        }
    }

    private func handle(_ snapshot: BodyPoseSnapshot) {
        let delta = timeSinceLastFrame(snapshot.timestamp)
        imageSize = snapshot.imageSize
        isBodyVisible = snapshot.hasAll(BodyPoseSnapshot.requiredForPlay)

        switch phase {
        case .calibrating:
            advanceCalibration(snapshot, delta: delta)
        case .starting(let remaining):
            advanceCountdown(remaining: remaining, delta: delta)
        case .playing:
            advancePlay(snapshot, delta: delta)
        case .tutorial, .preparing, .paused, .gameOver, .unavailable:
            break
        }

        logPoseIfRequested(snapshot)
    }

    private func timeSinceLastFrame(_ timestamp: TimeInterval) -> Double {
        defer { lastTimestamp = timestamp }
        guard let last = lastTimestamp else { return 0 }
        // Clamp so a stall between frames cannot jump a progress bar to full or
        // burn a whole cue window in one tick.
        return min(max(timestamp - last, 0), 0.2)
    }

    private func advanceCalibration(_ snapshot: BodyPoseSnapshot, delta: Double) {
        let ready = isBodyVisible && snapshot.isFullBodyInFrame()

        if ready {
            calibrationProgress = min(1, calibrationProgress + delta / Self.calibrationSeconds)
        } else {
            // Drain more slowly than it fills, so a single dropped frame does
            // not undo the player's progress.
            calibrationProgress = max(0, calibrationProgress - delta / Self.calibrationSeconds * 0.5)
        }

        guard calibrationProgress >= 1 else { return }
        audio.play(.calibrationComplete)
        audio.startBackgroundMusic(.gameplay)
        phase = .starting(remaining: Self.countdownSeconds)
    }

    private func advanceCountdown(remaining: Double, delta: Double) {
        let left = remaining - delta
        if left <= 0 {
            phase = .playing
            bodyLostSeconds = 0
        } else {
            phase = .starting(remaining: left)
        }
    }

    private func advancePlay(_ snapshot: BodyPoseSnapshot, delta: Double) {
        // Stepping out of shot cannot be scored either way, so the run is
        // suspended back to calibration rather than quietly draining Taksu.
        guard isBodyVisible else {
            bodyLostSeconds += delta
            if bodyLostSeconds >= Self.bodyLostGraceSeconds { beginCalibration() }
            return
        }
        bodyLostSeconds = 0

        let input = tracker.read(snapshot, delta: delta, cuedPose: cuedPose, rules: rules)
        advanceFootSparks(delta: delta)

        for event in run.advance(delta: delta, input: input) {
            react(to: event)
        }
    }

    /// Ages the sparks out and strikes one wherever a foot just landed.
    private func advanceFootSparks(delta: Double) {
        for index in footSparks.indices {
            footSparks[index].age += delta
        }
        footSparks.removeAll { $0.age >= rules.stepSparkSeconds }

        for step in tracker.lastSteps {
            footSparks.append(
                FootSpark(
                    position: step.position,
                    lifetime: rules.stepSparkSeconds * Double.random(in: 0.82...1.2),
                    seed: .random(in: UInt64.min...UInt64.max)
                )
            )
            audio.play(.footStep)
        }
    }

    // MARK: - Reacting to the loop

    private func react(to event: RunEvent) {
        switch event {
        case .ngayogCycle: audio.play(.ngayogCycle)
        case .coinCollected: audio.play(.coinCollected)
        case .squatCued: audio.play(.squatCue)
        case .squatHit: audio.play(.squatHit)
        case .squatMissed: audio.play(.squatMiss)
        case .squatBrokenEarly: audio.play(.squatBroken)
        case .squatHeldFully: audio.play(.squatHeld)
        case .freezeCued: audio.play(.freezeCue)
        case .freezeLocked: audio.play(.freezeLocked)
        case .freezeHeldFully: audio.play(.freezeHeld)
        case .freezeBrokenEarly: audio.play(.freezeBroken)
        case .freezeFailed: audio.play(.freezeFailed)
        case .energyLow: audio.play(.energyLow)
        case .gameOver(let score):
            audio.play(.gameOver)
            scores.record(ScoreRecord(score: score, survivedSeconds: run.elapsed))
            Task { await gameCenter.submit(score: score) }
            phase = .gameOver
        }

        // A ngayog tick and a coin both fire constantly and would drown out
        // everything else on screen, so they are heard but never flashed. The
        // coin has its own feedback where it was picked up.
        switch event {
        case .ngayogCycle, .coinCollected: return
        default: break
        }
        lastEvent = event
        lastEventAt = .now
    }

    /// Prints the current body in pose-definition coordinates once a second, so
    /// a new pose can be recorded by standing in it and copying the numbers.
    private func logPoseIfRequested(_ snapshot: BodyPoseSnapshot) {
        #if DEBUG
        guard DebugLaunchOptions.printsPoseCoordinates,
              snapshot.timestamp - lastPoseLog > 1,
              let frame = BodyFrame(snapshot: snapshot)
        else { return }
        lastPoseLog = snapshot.timestamp

        let lines = TrackedBodyPoint.allCases.compactMap { point -> String? in
            guard let position = snapshot.position(of: point.joint) else { return nil }
            let body = frame.normalize(position)
            return String(
                format: "{ \"point\": \"%@\", \"x\": %.2f, \"y\": %.2f, \"tolerance\": 0.45 },",
                point.rawValue, body.x, body.y
            )
        }
        Logger.poses.debug("Pose targets:\n\(lines.joined(separator: "\n"))")
        #endif
    }
}
