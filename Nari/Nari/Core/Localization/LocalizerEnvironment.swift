import SwiftUI

private struct LocalizerKey: EnvironmentKey {
    static let defaultValue = Localizer(language: .default)
}

extension EnvironmentValues {
    /// Injected once by `RootView` from the current `SettingsService` language,
    /// so views read strings without reaching into the settings service.
    var strings: Localizer {
        get { self[LocalizerKey.self] }
        set { self[LocalizerKey.self] = newValue }
    }
}
