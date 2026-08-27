import SwiftUI
import UIKit

/// Holds the display awake for as long as the modified view is on screen.
///
/// The game is danced several metres from the iPad with nobody touching the
/// glass, so the idle timer has nothing to reset it: without this the screen
/// dims and locks partway through a run, taking the camera preview and the
/// cues with it. Tied to the view's lifetime rather than set once globally, so
/// the menu, the settings popups and the credits still sleep normally.
private struct KeepScreenAwake: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

extension View {
    /// Keeps the device from sleeping while this view is on screen. iOS ignores
    /// the flag whenever the app is not frontmost, so backgrounding mid-run
    /// still lets the device sleep on its own schedule.
    func keepsScreenAwake() -> some View {
        modifier(KeepScreenAwake())
    }
}
