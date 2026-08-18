import Observation
import SwiftUI

/// Drives the main menu: the curtain choreography, which popup is up, and the
/// hand-off to the router when a session starts.
@MainActor
@Observable
final class MainMenuViewModel {

    enum Popup: String, Identifiable {
        case settings
        case credits

        var id: String { rawValue }
    }

    private(set) var curtainPhase: CurtainPhase = .open
    private(set) var isContentVisible = false
    private(set) var isTransitioning = false
    var activePopup: Popup?

    @ObservationIgnored private let audio: AudioServicing
    @ObservationIgnored private let onEnterGameplay: (GameMode) -> Void
    @ObservationIgnored private var hasPlayedEntrance = false
    @ObservationIgnored private var choreography: Task<Void, Never>?

    init(audio: AudioServicing, onEnterGameplay: @escaping (GameMode) -> Void) {
        self.audio = audio
        self.onEnterGameplay = onEnterGameplay
    }

    deinit {
        choreography?.cancel()
    }

    // MARK: - Lifecycle

    /// Curtains start swung aside and fall shut once, then the menu fades in on
    /// top of them.
    func onAppear() {
        guard !hasPlayedEntrance else { return }
        hasPlayedEntrance = true
        audio.startBackgroundMusic()

        choreography = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.15))
            guard let self, !Task.isCancelled else { return }

            withAnimation(Theme.Motion.curtainClose) {
                self.curtainPhase = .closed
            }

            try? await Task.sleep(for: .seconds(Theme.Motion.curtainCloseDuration * 0.6))
            guard !Task.isCancelled else { return }

            withAnimation(Theme.Motion.contentFade) {
                self.isContentVisible = true
            }

            #if DEBUG
            if let popup = DebugLaunchOptions.popup {
                self.present(popup)
            }
            if DebugLaunchOptions.autoStartsSession {
                self.select(.play)
            }
            #endif
        }
    }

    // MARK: - Input

    func select(_ item: MainMenuItem) {
        guard !isTransitioning else { return }
        audio.play(.buttonTap)

        switch item {
        case .play:
            startSession(mode: .play)
        case .settings:
            present(.settings)
        case .credits:
            present(.credits)
        }
    }

    func dismissPopup() {
        guard activePopup != nil else { return }
        audio.play(.popupClose)
        withAnimation(Theme.Motion.popup) {
            activePopup = nil
        }
    }

    // MARK: - Private

    private func present(_ popup: Popup) {
        audio.play(.popupOpen)
        withAnimation(Theme.Motion.popup) {
            activePopup = popup
        }
    }

    /// Fades the menu out, swings the curtains open, and only then tells the
    /// router to put the gameplay screen on stage.
    private func startSession(mode: GameMode) {
        isTransitioning = true
        activePopup = nil

        choreography?.cancel()
        choreography = Task { [weak self] in
            guard let self else { return }

            withAnimation(Theme.Motion.contentFade) {
                self.isContentVisible = false
            }

            try? await Task.sleep(for: .seconds(0.28))
            guard !Task.isCancelled else { return }

            self.audio.play(.curtainOpen)
            withAnimation(Theme.Motion.curtainOpen) {
                self.curtainPhase = .open
            }

            try? await Task.sleep(for: .seconds(Theme.Motion.curtainOpenDuration))
            guard !Task.isCancelled else { return }

            self.onEnterGameplay(mode)
        }
    }
}
