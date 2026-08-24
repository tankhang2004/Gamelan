import SwiftUI

/// Hosts whichever screen the router points at and injects the language-aware
/// string table for everything below it.
struct RootView: View {
    let services: AppServices
    @Bindable var router: AppRouter

    /// Held here rather than inside `GameplayView` so one session keeps one
    /// camera and one pose stream, however often the view body re-runs.
    @State private var gameplayViewModel: GameplayViewModel?

    var body: some View {
        ZStack {
            switch router.screen {
            case .mainMenu:
                MainMenuView(
                    viewModel: MainMenuViewModel(
                        audio: services.audio,
                        onEnterGameplay: { router.enterGameplay($0) }
                    ),
                    settings: services.settings,
                    credits: services.credits,
                    scores: services.scores,
                    gameCenter: services.gameCenter
                )
                .transition(.opacity)

            case .gameplay:
                gameplayScreen
                    .transition(.opacity)
            }
        }
        .environment(\.strings, services.settings.localizer)
        .animation(Theme.Motion.screenChange, value: router.screen)
        .ignoresSafeArea()
        .task {
            await services.gameCenter.authenticate()
            presentPendingGameCenterSignIn()
        }
    }

    /// The auth handler hands back a sign-in sheet rather than presenting it
    /// itself, so this is the one place in the app with a view controller to
    /// present it from.
    private func presentPendingGameCenterSignIn() {
        guard let viewController = GameCenterPresentation.pendingViewController else { return }
        GameCenterPresentation.pendingViewController = nil

        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow }?
            .rootViewController?
            .present(viewController, animated: true)
    }

    @ViewBuilder
    private var gameplayScreen: some View {
        if let gameplayViewModel {
            GameplayView(viewModel: gameplayViewModel, scores: services.scores)
        } else {
            Theme.Palette.ink
                .onAppear { gameplayViewModel = makeGameplayViewModel() }
        }
    }

    private func makeGameplayViewModel() -> GameplayViewModel {
        GameplayViewModel(
            poses: services.poses,
            source: services.makeBodyPoseSource(),
            audio: services.audio,
            scores: services.scores,
            gameCenter: services.gameCenter,
            onExit: {
                // Dropping the view model stops the camera and clears the session.
                gameplayViewModel = nil
                router.returnToMainMenu()
            }
        )
    }
}

#Preview {
    RootView(services: .preview(), router: AppRouter())
}
