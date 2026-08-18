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
                    credits: services.credits
                )
                .transition(.opacity)

            case .gameplay:
                gameplayScreen
                    .transition(.opacity)
            }
        }
        .environment(\.strings, services.settings.localizer)
        .animation(.easeInOut(duration: 0.25), value: router.screen)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var gameplayScreen: some View {
        if let gameplayViewModel {
            GameplayView(viewModel: gameplayViewModel)
        } else {
            Color.black
                .onAppear { gameplayViewModel = makeGameplayViewModel() }
        }
    }

    private func makeGameplayViewModel() -> GameplayViewModel {
        GameplayViewModel(
            pose: services.poses.pose(id: "agem") ?? .fallbackAgem,
            source: services.makeBodyPoseSource(),
            audio: services.audio,
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
