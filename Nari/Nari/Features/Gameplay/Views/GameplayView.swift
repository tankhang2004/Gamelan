import SwiftUI

/// The play session: placement tutorial, calibration, green room, then the
/// scored loop with the camera behind it.
struct GameplayView: View {
    /// Owned by `RootView` so the camera session survives view updates.
    let viewModel: GameplayViewModel
    let scores: ScoreHistoryStoring

    @Environment(\.strings) private var strings

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

            if viewModel.phase == .playing {
                hud
                    .transition(.opacity)
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

                if viewModel.run.phase.cuedSide != nil {
                    PoseMarkersView(
                        markers: viewModel.tracker.markers,
                        mapper: CameraFrameMapper(
                            imageSize: viewModel.imageSize,
                            viewSize: proxy.size,
                            isMirrored: viewModel.isPreviewMirrored
                        )
                    )
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
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Theme.Palette.cream)
                                .padding(16)
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

    @ViewBuilder
    private var cueCard: some View {
        if let pose = viewModel.cuedPose {
            PoseCueCard(
                title: pose.name(for: strings.language),
                artworkName: pose.artworkName,
                symbolName: "figure.stand"
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

    private var prompt: some View {
        let run = viewModel.run
        return Group {
            switch run.phase {
            case .ngayog:
                CuePromptView(text: strings[.cueWalk], progress: 0, tint: Theme.Palette.indigo)
            case .squatCue:
                CuePromptView(text: strings[.cueSquat], progress: run.phaseProgress, tint: Theme.Palette.cueOrange)
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
                VStack {
                    banner(
                        title: strings[.calibrationTitle],
                        subtitle: viewModel.isBodyVisible
                            ? strings[.calibrationInstruction]
                            : strings[.calibrationSearching]
                    )
                    Spacer()
                }
                .padding(.top, 40)

                StageProgressBorder(progress: viewModel.calibrationProgress, color: Theme.Palette.poseCorrect)
                    .padding(6)
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
                onShare: {},
                onDownload: {},
                onMenu: { viewModel.exit() }
            )

        case .tutorial, .playing, .unavailable:
            EmptyView()
        }
    }

    /// The green room: the track title and a countdown over a live preview, so
    /// the player has a moment to get set before scoring starts.
    private func greenRoom(remaining: Double) -> some View {
        ZStack {
            Theme.Palette.ink.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 18) {
                Text(strings[.greenRoomTrack])
                    .font(Theme.Fonts.label(26))
                    .foregroundStyle(Theme.Palette.cream.opacity(0.85))

                Text("\(Int(remaining.rounded(.up)))")
                    .font(Theme.Fonts.title(150))
                    .foregroundStyle(Theme.Palette.cream)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: Int(remaining.rounded(.up)))

                Text(strings[.greenRoomStart])
                    .font(Theme.Fonts.title(40))
                    .foregroundStyle(Theme.Palette.ochre)
            }
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
        case .freezeLocked: (strings[.flashLocked], Theme.Palette.poseCorrect)
        case .freezeHeldFully: (strings[.flashPerfect], Theme.Palette.ochre)
        case .freezeBrokenEarly: (strings[.flashBroke], Theme.Palette.cream)
        case .freezeFailed: (strings[.flashTooSlow], Theme.Palette.poseWrong)
        case .ngayogCycle, .squatCued, .freezeCued, .energyLow, .gameOver: nil
        }
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
            onExit: {}
        ),
        scores: services.scores
    )
    .environment(\.strings, Localizer(language: .english))
}
