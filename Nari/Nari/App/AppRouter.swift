import Observation

/// Top-level navigation state. The menu owns the curtain animation; the router
/// only records which screen is on stage once that animation finishes.
@MainActor
@Observable
final class AppRouter {
    enum Screen: Equatable {
        case mainMenu
        case gameplay(GameMode)
    }

    private(set) var screen: Screen = .mainMenu

    func enterGameplay(_ mode: GameMode) {
        screen = .gameplay(mode)
    }

    func returnToMainMenu() {
        screen = .mainMenu
    }
}
