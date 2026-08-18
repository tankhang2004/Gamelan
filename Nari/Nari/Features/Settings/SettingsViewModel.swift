import Observation

/// Editing surface for the settings popup. Holds no state of its own: every
/// write goes straight to `SettingsService`, which persists it and applies the
/// new volumes to the audio service.
@MainActor
@Observable
final class SettingsViewModel {
    @ObservationIgnored private let settings: SettingsService

    init(settings: SettingsService) {
        self.settings = settings
    }

    var musicVolume: Double {
        get { settings.settings.musicVolume }
        set { settings.setMusicVolume(newValue) }
    }

    var sfxVolume: Double {
        get { settings.settings.sfxVolume }
        set { settings.setSFXVolume(newValue) }
    }

    var language: AppLanguage {
        get { settings.settings.language }
        set { settings.setLanguage(newValue) }
    }

    let availableLanguages = AppLanguage.allCases

    func percentText(for volume: Double) -> String {
        "\(Int((volume * 100).rounded()))%"
    }
}
