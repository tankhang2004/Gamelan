import Observation
import SwiftUI

/// Drives the main menu: the entrance, which popup is up, and the hand-off to
/// the router when a session starts.
@MainActor
@Observable
final class MainMenuViewModel {

    enum Popup: String, Identifiable {
        case settings
        case credits
        case scores

        var id: String { rawValue }
    }

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

    func onAppear() {
        guard !hasPlayedEntrance else { return }
        hasPlayedEntrance = true
        audio.startBackgroundMusic()

        choreography = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.15))
            guard let self, !Task.isCancelled else { return }

            withAnimation(Theme.Motion.contentFade) {
                self.isContentVisible = true
            }

            #if DEBUG
            if let popup = DebugLaunchOptions.popup {
                self.present(popup)
            }
            if DebugLaunchOptions.autoStartsSession {
                self.play()
            }
            #endif
        }
    }

    // MARK: - Input

    func play() {
        guard !isTransitioning else { return }
        audio.play(.buttonTap)
        isTransitioning = true
        activePopup = nil

        choreography?.cancel()
        choreography = Task { [weak self] in
            guard let self else { return }

            withAnimation(Theme.Motion.contentFade) {
                self.isContentVisible = false
            }

            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }

            self.onEnterGameplay(.play)
        }
    }

    func select(_ item: MainMenuItem) {
        guard !isTransitioning else { return }
        audio.play(.buttonTap)

        switch item {
        case .settings: present(.settings)
        case .credits: present(.credits)
        case .scores: present(.scores)
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
}
