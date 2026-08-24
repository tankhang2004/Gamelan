import Observation

/// Single source of truth for player preferences.
///
/// Owns the model, pushes every change to the persistence store and to the
/// audio service, and publishes changes so the whole view tree (including the
/// language-dependent strings) stays in sync.
@MainActor
@Observable
final class SettingsService {
    private(set) var settings: GameSettings

    @ObservationIgnored private let store: SettingsStoring
    @ObservationIgnored private let audio: AudioServicing

    init(store: SettingsStoring, audio: AudioServicing) {
        self.store = store
        self.audio = audio
        self.settings = store.load()
        applyToAudio()
    }

    var localizer: Localizer { Localizer(language: settings.language) }

    func setMusicVolume(_ volume: Double) {
        guard settings.musicVolume != volume else { return }
        settings.musicVolume = volume
        audio.setMusicVolume(volume)
        persist()
    }

    func setSFXVolume(_ volume: Double) {
        guard settings.sfxVolume != volume else { return }
        settings.sfxVolume = volume
        audio.setSFXVolume(volume)
        persist()
    }

    func setCameraFieldOfView(_ fieldOfView: CameraFieldOfView) {
        guard settings.cameraFieldOfView != fieldOfView else { return }
        settings.cameraFieldOfView = fieldOfView
        persist()
    }

    func setLanguage(_ language: AppLanguage) {
        guard settings.language != language else { return }
        settings.language = language
        persist()
    }

    private func applyToAudio() {
        audio.setMusicVolume(settings.musicVolume)
        audio.setSFXVolume(settings.sfxVolume)
    }

    private func persist() {
        store.save(settings)
    }
}
