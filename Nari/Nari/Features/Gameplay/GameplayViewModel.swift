import AVFoundation
import CoreGraphics
import Foundation
import Observation
import OSLog

/// Runs a play session: the placement tutorial, the calibration hold, and the
/// pose loop. It owns the pose source and is the only place that decides which
/// phase the screen is in.
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
        case playing
        case paused
        case unavailable(Problem)

        enum Problem: Equatable {
            case permissionDenied
            case noCamera
        }
    }

    /// How long the whole body has to stay in frame before play starts.
    static let calibrationSeconds: Double = 3
    /// Losing the body for this long during play sends the player back to
    /// calibration rather than leaving the markers frozen on screen.
    private static let bodyLostGraceSeconds: Double = 2

    private(set) var phase: Phase = .tutorial
    private(set) var calibrationProgress: Double = 0
    private(set) var holdProgress: Double = 0
    private(set) var markers: [PoseEvaluation.Marker] = []
    private(set) var markerProgress: [TrackedBodyPoint: Double] = [:]
    private(set) var isBodyVisible = false
    private(set) var completedReps = 0
    private(set) var isCelebrating = false

    /// Size of the frames Vision is reading, needed to place markers over the
    /// aspect-filled preview.
    private(set) var imageSize: CGSize = .zero

    let pose: PoseDefinition

    @ObservationIgnored private let source: BodyPoseSource
    @ObservationIgnored private let audio: AudioServicing
    @ObservationIgnored private let onExit: () -> Void
    @ObservationIgnored private var consumer: Task<Void, Never>?
    @ObservationIgnored private var celebration: Task<Void, Never>?
    @ObservationIgnored private var lastTimestamp: TimeInterval?
    @ObservationIgnored private var bodyLostSeconds: Double = 0
    @ObservationIgnored private var lastPoseLog: TimeInterval = 0

    init(
        pose: PoseDefinition,
        source: BodyPoseSource,
        audio: AudioServicing,
        onExit: @escaping () -> Void
    ) {
        self.pose = pose
        self.source = source
        self.audio = audio
        self.onExit = onExit
    }

    deinit {
        consumer?.cancel()
        celebration?.cancel()
        source.stop()
    }

    var captureSession: AVCaptureSession? { source.captureSession }

    func attachPreview(_ layer: AVCaptureVideoPreviewLayer) {
        source.attachPreview(layer)
    }

    /// The preview is mirrored so the player sees themselves the way a mirror
    /// would show them; marker positions have to be flipped to match.
    var isPreviewMirrored: Bool { true }

    var titleKey: LocalizedKey { .gameplayPlayTitle }

    // MARK: - Session control

    func startSession() async {
        guard phase == .tutorial else { return }
        phase = .preparing

        do {
            try await source.start()
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
        audio.play(.buttonTap)
        // Come back through calibration so the player has time to get set again.
        beginCalibration()
    }

    func exit() {
        consumer?.cancel()
        celebration?.cancel()
        source.stop()
        onExit()
    }

    // MARK: - Frame handling

    private func beginCalibration() {
        phase = .calibrating
        calibrationProgress = 0
        holdProgress = 0
        markerProgress = [:]
        markers = []
        bodyLostSeconds = 0
        lastTimestamp = nil
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
        case .playing:
            advancePlay(snapshot, delta: delta)
        case .tutorial, .preparing, .paused, .unavailable:
            break
        }

        logPoseIfRequested(snapshot)
    }

    private func timeSinceLastFrame(_ timestamp: TimeInterval) -> Double {
        defer { lastTimestamp = timestamp }
        guard let last = lastTimestamp else { return 0 }
        // Clamp so a stall between frames cannot jump a progress bar to full.
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

        if calibrationProgress >= 1 {
            audio.play(.calibrationComplete)
            phase = .playing
            holdProgress = 0
            bodyLostSeconds = 0
        }
    }

    private func advancePlay(_ snapshot: BodyPoseSnapshot, delta: Double) {
        let evaluation = PoseEvaluator.evaluate(snapshot: snapshot, definition: pose)
        markers = evaluation.markers

        guard evaluation.hasAllPoints else {
            bodyLostSeconds += delta
            if bodyLostSeconds >= Self.bodyLostGraceSeconds {
                beginCalibration()
            }
            return
        }
        bodyLostSeconds = 0

        let step = delta / pose.holdSeconds
        for marker in evaluation.markers {
            let current = markerProgress[marker.point] ?? 0
            markerProgress[marker.point] = marker.isCorrect
                ? min(1, current + step)
                : max(0, current - step * 2)
        }

        if evaluation.isCorrect {
            holdProgress = min(1, holdProgress + step)
            if holdProgress >= 1 { completeRep() }
        } else {
            holdProgress = max(0, holdProgress - step)
        }
    }

    private func completeRep() {
        completedReps += 1
        holdProgress = 0
        markerProgress = [:]
        audio.play(.poseComplete)

        celebration?.cancel()
        isCelebrating = true
        celebration = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard let self, !Task.isCancelled else { return }
            self.isCelebrating = false
        }
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
