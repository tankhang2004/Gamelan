import SwiftUI

/// The play session: placement tutorial, calibration, green room, then the
/// scored loop with the camera behind it.
struct GameplayView: View {
    /// Owned by `RootView` so the camera session survives view updates.
    let viewModel: GameplayViewModel
    let scores: ScoreHistoryStoring

    @Environment(\.strings) private var strings
    @Environment(\.audio) private var audio
    @State private var discSpin: Double = 0

    var body: some View {
        ZStack {
            switch viewModel.phase {
            // `.preparing` stays on this screen rather than moving on to the
            // stage: it is the stretch where the camera is being switched on,
            // and the player is better told that under the button they just
            // pressed than shown an empty stage that looks like a hang.
            case .tutorial, .preparing:
                TutorialView(
                    session: viewModel.captureSession,
                    onPreviewReady: { viewModel.attachPreview($0) },
                    isStarting: viewModel.phase == .preparing,
                    onStart: { Task { await viewModel.startSession() } },
                    onBack: { viewModel.exit() }
                )
                .task { await viewModel.prepareCamera() }
                .transition(.opacity)

            case .unavailable(let problem):
                unavailable(problem)

            case .calibrating, .starting, .playing, .paused, .gameOver:
                stage
            }
        }
        .animation(Theme.Motion.screenChange, value: viewModel.phase)
        .ignoresSafeArea()
    }

    // MARK: - Stage

    /// The live picture, and over it a stage that stands up to gravity.
    ///
    /// The two are deliberately separate layers. Everything drawn over the
    /// picture goes inside `UprightStage` and turns with the phone — the HUD
    /// and the overlays pinned to the picture alike, because a stage turned
    /// to face gravity is measured in the very frame the levelled picture is
    /// drawn in, and the two only keep agreeing if they turn together.
    private var stage: some View {
        ZStack {
            Theme.Palette.ink
            cameraPicture

            UprightStage {
                GeometryReader { proxy in
                    ZStack {
                        // Turned with the rest of the stage rather than left
                        // with the picture: it stands in for a camera, but
                        // it is the only thing on this screen with words on
                        // it, and words want to be the right way up.
                        if viewModel.captureSession == nil {
                            simulatorStandIn
                        }

                        cameraOverlays
                        squatWave

                        if viewModel.phase == .playing {
                            hud
                                .transition(.opacity)

                            coins
                        }

                        cueTimerBorder
                        phaseOverlay
                        eventFlash
                        actionBanner
                    }
                    .environment(\.handScreenPositions, handScreenPositions(in: proxy))
                }
                .coordinateSpace(.named(GameplayStage.space))
            }
        }
    }

    /// The only layer left square to the window. `AVCaptureVideoPreviewLayer`
    /// levels its own content against gravity and crops it to its own bounds
    /// to do so, so turning the view it sits in would only turn the picture
    /// twice.
    @ViewBuilder
    private var cameraPicture: some View {
        if let session = viewModel.captureSession {
            CameraPreviewView(session: session) { layer in
                viewModel.attachPreview(layer)
            }
        }
    }

    /// The player's wrists, mapped from normalized image space onto this
    /// stage's own coordinates — the same trip a pose marker or a coin
    /// makes — so a `HandHoverButton` anywhere in the stage can compare its
    /// own frame against them directly.
    ///
    /// Counted from the stage's corner rather than the window's, because the
    /// stage is turned to face gravity and the window is not: a wrist and the
    /// button it is reaching for only agree while both are measured in the
    /// same frame.
    private func handScreenPositions(in proxy: GeometryProxy) -> [CGPoint] {
        let mapper = CameraFrameMapper(
            imageSize: viewModel.imageSize,
            viewSize: proxy.size,
            isMirrored: viewModel.isPreviewMirrored
        )
        return viewModel.handNormalizedPositions.map(mapper.point)
    }

    /// Everything pinned to the picture rather than to the screen. It lives
    /// on the upright stage with the HUD: the picture is levelled against
    /// gravity, so image space is a gravity-levelled space too, and a marker
    /// only lands on the body while the two are read the same way up.
    private var cameraOverlays: some View {
        GeometryReader { proxy in
            ZStack {
                let mapper = CameraFrameMapper(
                    imageSize: viewModel.imageSize,
                    viewSize: proxy.size,
                    isMirrored: viewModel.isPreviewMirrored
                )

                if viewModel.phase == .playing {
                    // Sparks are on the ground, so they sit under everything.
                    FootSparksView(sparks: viewModel.footSparks, mapper: mapper)
                }

                // Under the Leyak but over the player, so the flagged floor
                // reads as somewhere to step out of rather than something
                // painted on the lens.
                if case .leyakWarning(let column, let remaining) = viewModel.run.phase {
                    LeyakWarningView(
                        column: column,
                        progress: 1 - remaining / RunRules.default.leyakWarningSeconds,
                        mapper: mapper
                    )
                }

                // Over the player, because a Leyak the player is standing
                // behind is not a threat anyone would move away from.
                if case .leyakDive(let column, let progress) = viewModel.run.phase {
                    LeyakView(column: column, progress: progress, mapper: mapper)
                }

                if viewModel.run.phase.cuedSide != nil {
                    PoseMarkersView(markers: viewModel.tracker.markers, mapper: mapper)
                }
            }
        }
    }

    /// The simulator has no camera, so the fake dancer drives the markers over a
    /// painted ground instead of a video feed.
    private var simulatorStandIn: some View {
        ZStack(alignment: .bottom) {
            PaintTexture(seed: 31, base: Theme.Palette.paperShade, highlight: Theme.Palette.paper, shadow: Theme.Palette.ochreDeep)
            HStack(spacing: 6) {
                Image(systemName: "video.slash")
                Text(strings[.cameraMissingTitle])
            }
            .font(Theme.Fonts.label(15))
            .foregroundStyle(Theme.Palette.ink.opacity(0.45))
            .padding(.bottom, 24)
        }
    }

    // MARK: - HUD

    private var hud: some View {
        GeometryReader { proxy in
            // The readouts and the side margins are cut from the *shorter*
            // edge, the way `MenuLayout`'s furniture is. In landscape the
            // shorter edge is the height and none of this moves; in portrait
            // the height is the long edge, and measuring against it printed a
            // score and a clock so large that the two of them together were
            // wider than the frame holding them — a two-digit score was
            // already enough to push the clock off the screen.
            let shortSide = min(proxy.size.width, proxy.size.height)
            let sideInset = shortSide * 0.045
            // Kept on the height: this is the margin that holds the top row
            // clear of the notch and the bottom row clear of the home
            // indicator, and neither of those moved.
            let endInset = proxy.size.height * 0.045
            let readout = shortSide * 0.045
            let card = cueCardSize(in: proxy.size)

            ZStack {
                VStack {
                    HStack(alignment: .top) {
                        PaintSwatchReadout(text: "\(viewModel.run.score)", fontSize: readout)
                        Spacer(minLength: 0)
                        PaintSwatchReadout(text: viewModel.clockText, fontSize: readout)
                    }
                    Spacer(minLength: 0)
                }

                HStack {
                    TaksuMeterView(fraction: viewModel.run.energyFraction, isLow: viewModel.run.isEnergyLow)
                        .frame(width: proxy.size.width * 0.055)
                        .padding(.vertical, proxy.size.height * 0.14)
                    Spacer(minLength: 0)
                    cueCard
                        .frame(width: card.width, height: card.height)
                        .animation(Theme.Motion.cueDrop, value: cueCardIdentity)
                }

                // Hard against the top of the stage: the instruction is the
                // one thing on this screen the player has to read while
                // moving, and every point it sits down the picture is a point
                // further from where their eyes already are.
                VStack {
                    prompt(width: min(CuePromptView.designWidth, proxy.size.width - sideInset * 2))
                    Spacer(minLength: 0)
                }

                VStack {
                    Spacer(minLength: 0)
                    HStack {
                        Spacer(minLength: 0)
                        // Wearing the menu's own round button, so the one
                        // control on the stage looks like the controls
                        // everywhere else in the game.
                        HandHoverButton(action: { viewModel.pause() }) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 88 * 0.6, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 88, height: 88)
                                .background(Circle().fill(Theme.Palette.cueOrange))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, sideInset)
            .padding(.vertical, endInset)
        }
    }

    private func cueCardSize(in size: CGSize) -> (width: CGFloat, height: CGFloat) {
        guard size.height > size.width else {
            return (size.width * 0.19, size.height * 0.68)
        }
        let width = (size.width * 0.34).clamped(to: 132...260)
        return (width, min(width * 1.5, size.height * 0.34))
    }

    private var coins: some View {
        GeometryReader { proxy in
            CoinsView(
                placements: viewModel.coinPlacements,
                mapper: CameraFrameMapper(
                    imageSize: viewModel.imageSize,
                    viewSize: proxy.size,
                    isMirrored: viewModel.isPreviewMirrored
                )
            )
        }
    }

    /// Which card the slot is showing, so a transition fires whenever it
    /// changes — including to "nothing", once the intro march card times out.
    private var cueCardIdentity: String {
        if let pose = viewModel.cuedPose { return "pose-\(pose.artworkName)" }
        if viewModel.isSquatCued { return "ngeed" }
        return viewModel.showsMarchCard ? "march" : "none"
    }

    @ViewBuilder
    private var cueCard: some View {
        if let pose = viewModel.cuedPose {
            PoseCueCard(
                artworkName: pose.artworkName,
                symbolName: "figure.stand"
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else if viewModel.isSquatCued {
            PoseCueCard(
                artworkName: "PoseNgeed",
                symbolName: "figure.cooldown"
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else if viewModel.showsMarchCard {
            PoseCueCard(
                artworkName: "PoseNgayog",
                symbolName: "figure.walk"
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    /// A 0.5x/1x style toggle, so an iPad on a table can still take in a whole
    /// child without anyone having to move the furniture.
    private var fieldOfViewControl: some View {
        VStack(spacing: 10) {
            Text(strings[.cameraFieldHint])
                .stageCaption(size: 24, blockOpacity: 0.55)

            HStack(spacing: 0) {
                ForEach(CameraFieldOfView.allCases) { option in
                    let isOn = viewModel.fieldOfView == option

                    Button {
                        guard !isOn else { return }
                        viewModel.toggleFieldOfView()
                    } label: {
                        VStack(spacing: 1) {
                            Text(option.shortLabel)
                                .font(Theme.Fonts.readout(30))
                            Text(strings[option.labelKey])
                                .font(Theme.Fonts.body(20))
                        }
                        .foregroundStyle(isOn ? Theme.Palette.ink : Theme.Palette.cream)
                        .frame(width: 130, height: 78)
                        .background(
                            Capsule().fill(isOn ? Theme.Palette.ochre : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            .background(Capsule().fill(Theme.Palette.ink.opacity(0.72)))
            .overlay(Capsule().strokeBorder(Theme.Palette.cream.opacity(0.55), lineWidth: 3))
            .animation(Theme.Motion.popup, value: viewModel.fieldOfView)
        }
    }

    /// The wave the player has to stay under for the length of a nge'ed hold.
    @ViewBuilder
    private var squatWave: some View {
        if case .squatHold = viewModel.run.phase {
            SquatWaveView(progress: viewModel.run.phaseProgress)
        }
    }

    /// Seconds the march instruction gets before the banner hands off to the
    /// flower-collecting hint — long enough to read, short enough that the
    /// resting state of the game is "go pick flowers", not "walk forever".
    private static let marchInstructionSeconds: Double = 2

    private func prompt(width: CGFloat) -> some View {
        let run = viewModel.run
        return Group {
            switch run.phase {
            case .ngayog:
                if run.ngayogPhaseElapsed < Self.marchInstructionSeconds {
                    CuePromptView(text: strings[.cueWalk], backgroundAsset: "command-purple-walk", maxWidth: width)
                } else {
                    CuePromptView(text: strings[.cueCollectHint], backgroundAsset: "command-yellow-flower", maxWidth: width)
                }
            case .squatCue:
                CuePromptView(text: strings[.cueSquat], backgroundAsset: "command-orange-squat-hold", maxWidth: width)
            case .squatHold:
                CuePromptView(
                    text: strings[.cueHold],
                    backgroundAsset: "command-orange-squat-hold",
                    holdProgress: run.phaseProgress,
                    maxWidth: width
                )
            case .freezeGrace:
                CuePromptView(text: strings[.cueFreeze], backgroundAsset: "command-hit-pose-freeze", maxWidth: width)
            case .freezeHold:
                CuePromptView(
                    text: strings[.cueHold],
                    backgroundAsset: "command-hit-pose-freeze",
                    holdProgress: run.phaseProgress,
                    maxWidth: width
                )
            // The warning carries the same instruction as the dive, and is the
            // half of it the player can still act on.
            case .leyakWarning, .leyakDive:
                CuePromptView(text: strings[.cueLeyak], backgroundAsset: "command-red-leyak", maxWidth: width)
            case .gameOver:
                EmptyView()
            }
        }
        .animation(Theme.Motion.cueDrop, value: run.phase.isInterrupt)
    }

    /// Same corner spot, shape, and orange the tutorial's own back arrow uses
    /// — the player already learned that spot means "leave" before ever
    /// reaching calibration, so preparing and calibrating just keep it there.
    private var backToHomeCorner: some View {
        VStack {
            HStack {
                backToHomeButton
                    .offset(x: 40, y: 24)
                Spacer()
            }
            Spacer()
        }
        .padding(28)
    }

    /// The tutorial's plain tap-only arrow, wearing the same hover-to-select
    /// dwell the pause button uses — hands are already up mid-calibration, so
    /// leaving shouldn't require walking back to the iPad either.
    private var backToHomeButton: some View {
        HandHoverButton(action: { viewModel.exit() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 64 * 0.6, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Theme.Palette.cueOrange))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var phaseOverlay: some View {
        switch viewModel.phase {
        case .calibrating:
            ZStack {
//                Image("overlay-calib")
//                    .resizable()
//                    .scaledToFill()
//                    .ignoresSafeArea()

                VStack {
                    Text(calibrationMessage)
                        .multilineTextAlignment(.center)
                        .stageCaption(size: 46)
                        .padding(.horizontal, 48)
                    Spacer()
                }
                .padding(.top, 56)

                StageProgressBorder(progress: viewModel.calibrationProgress, color: Theme.Palette.poseCorrect)
                    .padding(6)

                // Calibration is the moment the player is looking at their own
                // feet wondering why they are cut off, so the control belongs
                // here rather than buried in Settings.
                if viewModel.canChangeFieldOfView {
                    VStack {
                        Spacer()
                        fieldOfViewControl
                            .padding(.bottom, 46)
                    }
                }

                backToHomeCorner
            }

        case .starting(let remaining):
            greenRoom(remaining: remaining)

        case .paused:
            pauseOverlay

        case .gameOver:
            GameOverView(
                score: viewModel.run.score,
                survived: viewModel.clockText,
                isBest: scores.best.map { $0.score <= viewModel.run.score } ?? true,
                bestScore: scores.best?.score ?? 0,
                videoURL: viewModel.recordedVideoURL,
                isPreparingVideo: viewModel.isPreparingRecording,
                onRetry: { viewModel.retry() },
                onMenu: { viewModel.exit() }
            )

        // `.preparing` never reaches the stage — it is drawn by `TutorialView`.
        case .tutorial, .preparing, .playing, .unavailable:
            EmptyView()
        }
    }

    /// The green room: a "Game is Starting!" banner that burns off to reveal
    /// the track card, so the player knows what's about to play before
    /// scoring starts.
    private func greenRoom(remaining: Double) -> some View {
        // The banner holds for the first two thirds of the countdown, then
        // crossfades into the track card for what's left.
        let bannerOpacity = min(1, max(0, (remaining - 1) / 1))

        return ZStack {
            Theme.Palette.ink.opacity(0.45).ignoresSafeArea()

            startingBanner
                .opacity(bannerOpacity)
                .scaleEffect(0.92 + 0.08 * bannerOpacity)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    trackCard
                        .opacity(1 - bannerOpacity)
                }
            }
            .padding(28)
        }
        .animation(.easeInOut(duration: 0.3), value: bannerOpacity)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                discSpin = 360
            }
        }
    }

    private var startingBanner: some View {
        Text(strings[.startingTitle])
            .font(Theme.Fonts.title(56))
            .foregroundStyle(.white)
            .shadow(color: Theme.Palette.ink.opacity(0.85), radius: 8, y: 5)
            .shadow(color: Theme.Palette.ink.opacity(0.55), radius: 2, y: 2)
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .background(
                Image("yellow-stroke")
                    .resizable()
                    .scaledToFill()
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var trackCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "opticaldisc")
                .font(.system(size: 24))
                .foregroundStyle(Theme.Palette.ink)
                .rotationEffect(.degrees(discSpin))

            VStack(alignment: .leading, spacing: 2) {
                Text(strings[.greenRoomTrack])
                    .font(Theme.Fonts.label(19))
                    .foregroundStyle(Theme.Palette.ink)
                Text(strings[.greenRoomArtist])
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Palette.ink.opacity(0.7))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Image("bg-yellow-2")
                .resizable()
                .scaledToFill()
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// The cue window, drawn the same way calibration draws its hold: a border
    /// closing round the whole stage. One language for "time is running" on
    /// this screen, in a colour that is never the calibration green so the two
    /// are never mistaken for each other.
    ///
    /// Skipped for the two hold phases — `squatHold` and `freezeHold` already
    /// count the same window with `HoldCountdownBar`, right under the
    /// instruction the player is already looking at. Ringing the whole stage
    /// too said the same thing twice in two different places.
    @ViewBuilder
    private var cueTimerBorder: some View {
        if let timer = cueTimer {
            StageProgressBorder(progress: timer.progress, color: timer.color)
                .padding(6)
        }
    }

    private var cueTimer: (progress: Double, color: Color)? {
        let run = viewModel.run
        switch run.phase {
        case .squatCue:
            return (run.phaseProgress, Theme.Palette.cueOrange)
        case .freezeGrace:
            return (run.phaseProgress, Theme.Palette.gameOverPink)
        case .leyakWarning, .leyakDive:
            return (run.phaseProgress, Theme.Palette.gameOverPink)
        case .squatHold, .freezeHold, .ngayog, .gameOver:
            return nil
        }
    }

    /// The painted verdict thrown up big in the middle after a move — praise
    /// for a hold ridden all the way out, and the matching complaint for one
    /// that was fluffed.
    @ViewBuilder
    private var actionBanner: some View {
        if let artwork = actionBannerArtwork {
            GreatBanner(artworkName: artwork, stamp: viewModel.lastEventAt)
        }
    }

    /// The painted verdict for whatever the player just did — the loudest
    /// thing the game can say, so it is reserved for the moves that were
    /// actually asked for rather than for every tick of the loop.
    private var actionBannerArtwork: String? {
        switch viewModel.lastEvent {
        case .squatHeldFully: "great-squat"
        case .freezeHeldFully: "great-agem"
        case .squatBrokenEarly: "bad-squat-hold-fail"
        case .squatMissed: "too-slow-squat-fail"
        case .freezeFailed: "so-close"
        default: nil
        }
    }

    /// A short flash naming what just happened, so a hit or a miss is legible
    /// without watching the meter.
    @ViewBuilder
    private var eventFlash: some View {
        if let event = viewModel.lastEvent, let text = flashText(for: event) {
            VStack {
                Spacer()
                Text(text.label)
                    .font(Theme.Fonts.title(52))
                    .foregroundStyle(text.color)
                    .shadow(color: Theme.Palette.ink, radius: 0, x: 3, y: 3)
                    // "KENA LEYAK!" at fifty-two points is wider than a phone
                    // held upright, and this shares the stage's `ZStack` with
                    // the HUD — so left to its own width it would not simply
                    // run off the edge, it would take the HUD off with it.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 90)
            }
            .id(viewModel.lastEventAt)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: viewModel.lastEventAt)
            .allowsHitTesting(false)
        }
    }

    /// Only the moments with no painted banner of their own land here — the
    /// rest are announced by `actionBanner`, and saying it twice at two sizes
    /// reads as a bug rather than as emphasis.
    private func flashText(for event: RunEvent) -> (label: String, color: Color)? {
        switch event {
        case .squatHit: (strings[.flashNice], Theme.Palette.poseCorrect)
        case .freezeLocked: (strings[.flashLocked], Theme.Palette.poseCorrect)
        case .leyakHit: (strings[.flashCaught], Theme.Palette.poseWrong)
        case .ngayogCycle, .coinSpawned, .coinCollected, .squatCued, .freezeCued,
             .leyakCued, .leyakDodged, .squatMissed, .squatBrokenEarly,
             .squatHeldFully, .freezeBrokenEarly, .freezeHeldFully,
             .freezeFailed, .energyLow, .gameOver: nil
        }
    }

    /// Head-to-toe framing check, then "Calibrating..." for the whole hold.
    private var calibrationMessage: String {
        viewModel.isBodyVisible ? strings[.calibrationInstruction] : strings[.calibrationSearching]
    }

    private func banner(title: String, subtitle: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(Theme.Fonts.label(22))
                .foregroundStyle(Theme.Palette.ink)
            Text(subtitle)
                .font(Theme.Fonts.body(16))
                .foregroundStyle(Theme.Palette.ink.opacity(0.75))
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 14)
        .background(Capsule().fill(Theme.Palette.paper.opacity(0.94)))
        .overlay(Capsule().strokeBorder(Theme.Palette.ink, lineWidth: 4))
        .shadow(color: Theme.Palette.ink.opacity(0.35), radius: 10, y: 4)
    }

    private var pauseOverlay: some View {
        ZStack {
            Theme.Palette.scrim.ignoresSafeArea()

            // Exit lives in its own corner, well clear of Resume — with a
            // two-second hold, a hand hovering anywhere near the middle of
            // the screen should only ever be able to mean "resume".
            VStack {
                HStack {
                    exitCornerButton
                    Spacer()
                }
                Spacer()
            }
            .padding(28)

            VStack(spacing: 28) {
                Text(strings[.playPause])
                    .font(Theme.Fonts.title(52))
                    .foregroundStyle(Theme.Palette.ochre)

                HandHoverButton(action: { viewModel.resume() }) {
                    Label(strings[.playResume], systemImage: "play.fill")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .tracking(32 * 0.05)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80 * 0.65)
                        .frame(height: 80)
                        .background(Capsule().fill(Theme.Palette.indigo))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// A small, deliberately unassuming badge, so leaving mid-session is
    /// never the thing a hovering hand lands on by accident.
    private var exitCornerButton: some View {
        HandHoverButton(action: { viewModel.exit() }) {
            VStack(spacing: 3) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                Text(strings[.playExit])
                    .font(Theme.Fonts.label(12))
            }
            .foregroundStyle(.white)
            .frame(width: 72, height: 72)
            .background(Circle().fill(Theme.Palette.cueOrange))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Camera problems

    private func unavailable(_ problem: GameplayViewModel.Phase.Problem) -> some View {
        let isPermission = problem == .permissionDenied

        // Upright like the rest of the session. This is the one screen with
        // nothing but words on it, and words are the thing a sideways screen
        // costs the most.
        return UprightStage {
            ZStack {
                PaintTexture()

                VStack(spacing: 16) {
                    Image(systemName: isPermission ? "lock.slash" : "video.slash")
                        .font(.system(size: 46))
                        .foregroundStyle(Theme.Palette.indigo)

                    Text(strings[isPermission ? .cameraDeniedTitle : .cameraMissingTitle])
                        .font(Theme.Fonts.title(34))
                        .foregroundStyle(Theme.Palette.ink)

                    Text(strings[isPermission ? .cameraDeniedBody : .cameraMissingBody])
                        .font(Theme.Fonts.body(18))
                        .foregroundStyle(Theme.Palette.ink.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)

                    HStack(spacing: 14) {
                        if isPermission {
                            Button(strings[.cameraOpenSettings]) {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                UIApplication.shared.open(url)
                            }
                            .buttonStyle(PopupActionButtonStyle())
                        }

                        Button(strings[.gameplayBack]) {
                            audio.play(.buttonTap)
                            viewModel.exit()
                        }
                            .buttonStyle(.plain)
                            .font(Theme.Fonts.label(19))
                            .foregroundStyle(Theme.Palette.ink.opacity(0.75))
                    }
                }
                .padding(40)
            }
        }
    }
}

#Preview {
    let services = AppServices.preview()
    return GameplayView(
        viewModel: GameplayViewModel(
            poses: services.poses,
            source: SimulatedBodyPoseSource(),
            audio: services.audio,
            scores: services.scores,
            gameCenter: services.gameCenter,
            settings: services.settings,
            onExit: {}
        ),
        scores: services.scores
    )
    .environment(\.strings, Localizer(language: .english))
}
