import Foundation

/// Player preferences that survive between launches.
struct GameSettings: Codable, Equatable, Sendable {
    /// Background music level, 0...1.
    var musicVolume: Double
    /// Sound effect level, 0...1.
    var sfxVolume: Double
    var language: AppLanguage

    static let `default` = GameSettings(
        musicVolume: 0.7,
        sfxVolume: 0.8,
        language: .default
    )
}
