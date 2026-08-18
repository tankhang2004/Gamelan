import Foundation

/// Persistence seam for `GameSettings`. Kept as a protocol so previews and tests
/// can swap in an in-memory store.
protocol SettingsStoring {
    func load() -> GameSettings
    func save(_ settings: GameSettings)
}

/// Stores the settings as a single JSON blob in `UserDefaults`.
struct UserDefaultsSettingsStore: SettingsStoring {
    private let defaults: UserDefaults
    private let key = "com.yuknari.gameSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> GameSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(GameSettings.self, from: data)
        else { return .default }
        return settings
    }

    func save(_ settings: GameSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Non-persisting store for previews and tests.
final class InMemorySettingsStore: SettingsStoring {
    private var settings: GameSettings

    init(settings: GameSettings = .default) {
        self.settings = settings
    }

    func load() -> GameSettings { settings }
    func save(_ settings: GameSettings) { self.settings = settings }
}
