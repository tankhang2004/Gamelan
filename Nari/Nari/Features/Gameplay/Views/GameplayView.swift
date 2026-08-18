import SwiftUI

/// The play session: placement tutorial, calibration, then the pose loop with
/// the camera behind it.
struct GameplayView: View {
    /// Owned by `RootView` so the camera session survives view updates.
    let viewModel: GameplayViewModel

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

            case .preparing, .calibrating, .playing, .paused:
                stage
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
        .ignoresSafeArea()
    }

    // MARK: - Stage

    private var showsPanel: Bool {
        viewModel.phase == .playing || viewModel.phase == .paused
    }

    private var borderProgress: Double {
        switch viewModel.phase {
        case .calibrating: viewModel.calibrationProgress
        case .playing: viewModel.holdProgress
        default: 0
        }
    }

    private var stage: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                cameraArea

                if showsPanel {
                    PoseInstructionPanel(
                        pose: viewModel.pose,
                        language: strings.language,
                        completedReps: viewModel.completedReps,
                        holdProgress: viewModel.holdProgress,
                        onPause: { viewModel.pause() }
                    )
                    .frame(width: min(300, proxy.size.width * 0.25))
                    .transition(.move(edge: .trailing))
                }
            }
            .overlay {
                StageProgressBorder(progress: borderProgress, color: Theme.Palette.poseCorrect)
                    .padding(5)
            }
            .overlay { phaseOverlay }
            .overlay { celebration }
            .animation(.easeInOut(duration: 0.35), value: showsPanel)
        }
        .background(Color.black)
    }

    private var cameraArea: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                if let session = viewModel.captureSession {
                    CameraPreviewView(session: session) { layer in
                        viewModel.attachPreview(layer)
                    }
                } else {
                    simulatorStandIn
                }

                if viewModel.phase == .playing {
                    PoseMarkersView(
                        markers: viewModel.markers,
                        progress: viewModel.markerProgress,
                        mapper: CameraFrameMapper(
                            imageSize: viewModel.imageSize,
                            viewSize: proxy.size,
                            isMirrored: viewModel.isPreviewMirrored
                        ),
                        showsTargets: true
                    )
                }
            }
        }
    }

    /// The simulator has no camera, so the fake pose source drives the markers
    /// over a plain stage instead of a video feed.
    private var simulatorStandIn: some View {
        ZStack(alignment: .bottom) {
            StageBackdropView()
            HStack(spacing: 6) {
                Image(systemName: "video.slash")
                Text(strings[.cameraMissingTitle])
            }
            .font(Theme.Fonts.label(14))
            .foregroundStyle(Theme.Palette.parchment.opacity(0.4))
            .padding(.bottom, 24)
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private var phaseOverlay: some View {
        switch viewModel.phase {
        case .preparing:
            banner(title: strings[.calibrationTitle], subtitle: strings[.calibrationSearching])

        case .calibrating:
            VStack {
                banner(
                    title: strings[.calibrationTitle],
                    subtitle: viewModel.isBodyVisible
                        ? strings[.calibrationInstruction]
                        : strings[.calibrationSearching]
                )
                Spacer()
            }
            .padding(.top, 26)

        case .playing:
            VStack {
                banner(title: viewModel.pose.name(for: strings.language),
                       subtitle: strings[.playHoldInstruction])
                Spacer()
            }
            .padding(.top, 26)

        case .paused:
            pauseOverlay

        case .tutorial, .unavailable:
            EmptyView()
        }
    }

    private func banner(title: String, subtitle: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(Theme.Fonts.label(20))
                .foregroundStyle(Theme.Palette.ink)
            Text(subtitle)
                .font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Palette.ink.opacity(0.75))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(Capsule().fill(Theme.Palette.parchment.opacity(0.92)))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 22) {
                Text(strings[.playPause])
                    .font(Theme.Fonts.title(38))
                    .foregroundStyle(Theme.Palette.curtainGold)

                Button(strings[.playResume]) { viewModel.resume() }
                    .buttonStyle(PopupActionButtonStyle())

                Button(strings[.playExit]) { viewModel.exit() }
                    .buttonStyle(.plain)
                    .font(Theme.Fonts.label(18))
                    .foregroundStyle(Theme.Palette.parchment.opacity(0.85))
            }
        }
    }

    @ViewBuilder
    private var celebration: some View {
        if viewModel.isCelebrating {
            Text(strings[.playWellDone])
                .font(Theme.Fonts.title(64))
                .foregroundStyle(Theme.Palette.poseCorrect)
                .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.isCelebrating)
        }
    }

    // MARK: - Camera problems

    private func unavailable(_ problem: GameplayViewModel.Phase.Problem) -> some View {
        let isPermission = problem == .permissionDenied

        return ZStack {
            StageBackdropView()

            VStack(spacing: 16) {
                Image(systemName: isPermission ? "lock.slash" : "video.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.Palette.curtainGold)

                Text(strings[isPermission ? .cameraDeniedTitle : .cameraMissingTitle])
                    .font(Theme.Fonts.title(30))
                    .foregroundStyle(Theme.Palette.parchment)

                Text(strings[isPermission ? .cameraDeniedBody : .cameraMissingBody])
                    .font(Theme.Fonts.body(17))
                    .foregroundStyle(Theme.Palette.parchment.opacity(0.75))
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
                        .font(Theme.Fonts.label(18))
                        .foregroundStyle(Theme.Palette.parchment.opacity(0.85))
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
            pose: .fallbackAgem,
            source: SimulatedBodyPoseSource(),
            audio: services.audio,
            onExit: {}
        )
    )
    .environment(\.strings, Localizer(language: .indonesian))
}
