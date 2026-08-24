import Foundation

/// Player preferences that survive between launches.
struct GameSettings: Codable, Equatable, Sendable {
    /// Background music level, 0...1.
    var musicVolume: Double
    /// Sound effect level, 0...1.
    var sfxVolume: Double
    var language: AppLanguage
    /// How much of the room the camera takes in. Wide by default: it is the
    /// setting that copes with a badly placed iPad, and the one a child who
    /// cannot fit in frame needs without knowing to go looking for it.
    var cameraFieldOfView: CameraFieldOfView

    static let `default` = GameSettings(
        musicVolume: 0.7,
        sfxVolume: 0.8,
        language: .default,
        cameraFieldOfView: .wide
    )

    /// Decoded field by field so that adding a setting cannot throw away
    /// everything a player has already chosen.
    ///
    /// `UserDefaultsSettingsStore` falls back to `.default` on any decode
    /// error, so a synthesised initialiser would silently reset the volumes and
    /// the language of every existing install the first time a new key appeared.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = GameSettings.default
        musicVolume = try container.decodeIfPresent(Double.self, forKey: .musicVolume)
            ?? fallback.musicVolume
        sfxVolume = try container.decodeIfPresent(Double.self, forKey: .sfxVolume)
            ?? fallback.sfxVolume
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language)
            ?? fallback.language
        cameraFieldOfView = try container.decodeIfPresent(CameraFieldOfView.self, forKey: .cameraFieldOfView)
            ?? fallback.cameraFieldOfView
    }

    init(musicVolume: Double, sfxVolume: Double, language: AppLanguage, cameraFieldOfView: CameraFieldOfView) {
        self.musicVolume = musicVolume
        self.sfxVolume = sfxVolume
        self.language = language
        self.cameraFieldOfView = cameraFieldOfView
    }
}
