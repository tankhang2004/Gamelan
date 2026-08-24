import SwiftUI

/// The play session: placement tutorial, calibration, green room, then the
/// scored loop with the camera behind it.
struct GameplayView: View {
    /// Owned by `RootView` so the camera session survives view updates.
    let viewModel: GameplayViewModel
    let scores: ScoreHistoryStoring

    @Environment(\.strings) private var strings
    @State private var discSpin: Double = 0

    var body: some View {
        ZStack {
            switch viewModel.phase {
            case .tutorial:
                TutorialView(
                    onStart: { Task { await viewModel.startSession() } },
                    onBack: { viewModel.exit() }
                )
                .transition(.opacity)

            case .unavailable(let problem):
                unavailable(problem)

            case .preparing, .calibrating, .starting, .playing, .paused, .gameOver:
                stage
            }
        }
        .animation(Theme.Motion.screenChange, value: viewModel.phase)
        .ignoresSafeArea()
    }

    // MARK: - Stage

    private var stage: some View {
        ZStack {
            cameraArea

            // Over the player but under the HUD: the wave is scenery, and the
            // score and the hold timer have to stay readable through it.
            squatWave

            if viewModel.phase == .playing {
                hud
                    .transition(.opacity)

                // Over the HUD, not under it. Coins are chased now rather than
                // reached for, which means they land near the edges where the
                // meter and the move card live — and a coin hidden behind the
                // furniture is one nobody goes after.
                coins
            }

            phaseOverlay
            eventFlash
        }
        .overlay { freezeFrame }
        .background(Theme.Palette.ink)
    }

    private var cameraArea: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.Palette.ink

                if let session = viewModel.captureSession {
                    CameraPreviewView(session: session) { layer in
                        viewModel.attachPreview(layer)
                    }
                } else {
                    simulatorStandIn
                }

                let mapper = CameraFrameMapper(
                    imageSize: viewModel.imageSize,
                    viewSize: proxy.size,
                    isMirrored: viewModel.isPreviewMirrored
                )

                if viewModel.phase == .playing {
                    // Sparks are on the ground, so they sit under everything.
                    FootSparksView(sparks: viewModel.footSparks, mapper: mapper)
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
            let inset = proxy.size.height * 0.045

            ZStack {
                VStack {
                    HStack(alignment: .top) {
                        PaintSwatchReadout(text: "\(viewModel.run.score)", fontSize: proxy.size.height * 0.045)
                        Spacer(minLength: 0)
                        PaintSwatchReadout(
                            text: viewModel.clockText,
                            fill: Theme.Palette.ochre,
                            textColor: Theme.Palette.ink,
                            fontSize: proxy.size.height * 0.045,
                            seed: 8
                        )
                    }
                    Spacer(minLength: 0)
                }

                HStack {
                    TaksuMeterView(fraction: viewModel.run.energyFraction, isLow: viewModel.run.isEnergyLow)
                        .frame(width: proxy.size.width * 0.055)
                        .padding(.vertical, proxy.size.height * 0.14)
                    Spacer(minLength: 0)
                    cueCard
                        .frame(width: proxy.size.width * 0.19)
                        .padding(.vertical, proxy.size.height * 0.16)
                }

                VStack {
                    Spacer().frame(height: proxy.size.height * 0.14)
                    prompt
                    Spacer(minLength: 0)
                }

                VStack {
                    Spacer(minLength: 0)
                    HStack {
                        Spacer(minLength: 0)
                        Button(action: { viewModel.pause() }) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Theme.Palette.cream)
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(Theme.Palette.indigo))
                                .overlay(Circle().strokeBorder(Theme.Palette.ink, lineWidth: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(inset)
        }
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

    @ViewBuilder
    private var cueCard: some View {
        if let pose = viewModel.cuedPose {
            PoseCueCard(
                title: pose.name(for: strings.language),
                artworkName: pose.artworkName,
                symbolName: "figure.stand"
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else if viewModel.isSquatCued {
            PoseCueCard(
                title: strings[.cueNgeed],
                artworkName: "PoseNgeed",
                symbolName: "figure.cooldown"
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            PoseCueCard(
                title: strings[.cueNgayog],
                artworkName: "PoseNgayog",
                symbolName: "figure.walk"
            )
        }
    }

    /// A 0.5x/1x style toggle, so an iPad on a table can still take in a whole
    /// child without anyone having to move the furniture.
    private var fieldOfViewControl: some View {
        VStack(spacing: 10) {
            Text(strings[.cameraFieldHint])
                .font(Theme.Fonts.body(17))
                .foregroundStyle(Theme.Palette.cream.opacity(0.9))
                .shadow(color: Theme.Palette.ink, radius: 0, x: 2, y: 2)

            HStack(spacing: 0) {
                ForEach(CameraFieldOfView.allCases) { option in
                    let isOn = viewModel.fieldOfView == option

                    Button {
                        guard !isOn else { return }
                        viewModel.toggleFieldOfView()
                    } label: {
                        VStack(spacing: 1) {
                            Text(option.shortLabel)
                                .font(Theme.Fonts.readout(23))
                            Text(strings[option.labelKey])
                                .font(Theme.Fonts.body(14))
                        }
                        .foregroundStyle(isOn ? Theme.Palette.ink : Theme.Palette.cream)
                        .frame(width: 104, height: 62)
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

    private var prompt: some View {
        let run = viewModel.run
        return Group {
            switch run.phase {
            case .ngayog:
                CuePromptView(text: strings[.cueWalk], progress: 0, tint: Theme.Palette.indigo)
            case .squatCue:
                CuePromptView(text: strings[.cueSquat], progress: run.phaseProgress, tint: Theme.Palette.cueOrange)
            case .squatHold:
                CuePromptView(text: strings[.cueHold], progress: 1 - run.phaseProgress, tint: Theme.Palette.poseCorrect)
            case .freezeGrace:
                CuePromptView(text: strings[.cueFreeze], progress: run.phaseProgress, tint: Theme.Palette.gameOverPink)
            case .freezeHold:
                CuePromptView(text: strings[.cueHold], progress: 1 - run.phaseProgress, tint: Theme.Palette.poseCorrect)
            case .gameOver:
                EmptyView()
            }
        }
        .animation(Theme.Motion.cueDrop, value: run.phase.isInterrupt)
    }

    /// The Freeze cue is signalled by the music cutting out, which is no signal
    /// at all to a player who is hard of hearing or in a noisy room. The orange
    /// frame appears at the same instant so the cue is never audio-only.
    @ViewBuilder
    private var freezeFrame: some View {
        if case .freezeGrace = viewModel.run.phase {
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(Theme.Palette.cueOrange, lineWidth: 26)
                .ignoresSafeArea()
                .transition(.opacity)
                .animation(.easeOut(duration: 0.15), value: viewModel.run.phase)
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private var phaseOverlay: some View {
        switch viewModel.phase {
        case .preparing:
            banner(title: strings[.calibrationTitle], subtitle: strings[.calibrationSearching])

        case .calibrating:
            ZStack {
//                Image("overlay-calib")
//                    .resizable()
//                    .scaledToFill()
//                    .ignoresSafeArea()

                VStack {
                    Text(calibrationMessage)
                        .font(Theme.Fonts.body(40))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
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
                onRetry: { viewModel.retry() },
                onMenu: { viewModel.exit() }
            )

        case .tutorial, .playing, .unavailable:
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
            .foregroundStyle(Theme.Palette.indigo)
            .shadow(color: .white, radius: 0, x: 2, y: 0)
            .shadow(color: .white, radius: 0, x: -2, y: 0)
            .shadow(color: .white, radius: 0, x: 0, y: 2)
            .shadow(color: .white, radius: 0, x: 0, y: -2)
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
                    .padding(.bottom, 90)
            }
            .id(viewModel.lastEventAt)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: viewModel.lastEventAt)
            .allowsHitTesting(false)
        }
    }

    private func flashText(for event: RunEvent) -> (label: String, color: Color)? {
        switch event {
        case .squatHit: (strings[.flashNice], Theme.Palette.poseCorrect)
        case .squatMissed: (strings[.flashMissed], Theme.Palette.poseWrong)
        case .squatHeldFully: (strings[.flashPerfect], Theme.Palette.ochre)
        case .squatBrokenEarly: (strings[.flashBroke], Theme.Palette.cream)
        case .freezeLocked: (strings[.flashLocked], Theme.Palette.poseCorrect)
        case .freezeHeldFully: (strings[.flashPerfect], Theme.Palette.ochre)
        case .freezeBrokenEarly: (strings[.flashBroke], Theme.Palette.cream)
        case .freezeFailed: (strings[.flashTooSlow], Theme.Palette.poseWrong)
        case .ngayogCycle, .coinCollected, .squatCued, .freezeCued, .energyLow, .gameOver: nil
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

            VStack(spacing: 24) {
                Text(strings[.playPause])
                    .font(Theme.Fonts.title(52))
                    .foregroundStyle(Theme.Palette.ochre)

                Button(strings[.playResume]) { viewModel.resume() }
                    .buttonStyle(PopupActionButtonStyle())

                Button(strings[.playExit]) { viewModel.exit() }
                    .buttonStyle(.plain)
                    .font(Theme.Fonts.label(19))
                    .foregroundStyle(Theme.Palette.cream.opacity(0.85))
            }
        }
    }

    // MARK: - Camera problems

    private func unavailable(_ problem: GameplayViewModel.Phase.Problem) -> some View {
        let isPermission = problem == .permissionDenied

        return ZStack {
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

                    Button(strings[.gameplayBack]) { viewModel.exit() }
                        .buttonStyle(.plain)
                        .font(Theme.Fonts.label(19))
                        .foregroundStyle(Theme.Palette.ink.opacity(0.75))
                }
            }
            .padding(40)
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
            settings: services.settings,
            onExit: {}
        ),
        scores: services.scores
    )
    .environment(\.strings, Localizer(language: .english))
}
