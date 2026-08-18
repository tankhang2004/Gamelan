import Foundation

/// Languages the game can be played in. Stored in `GameSettings` and used by
/// `Localizer` to pick a string table at runtime, so switching is instant and
/// does not require relaunching the app.
enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case indonesian = "id"
    case english = "en"

    var id: String { rawValue }

    /// Name shown in the settings picker, always written in the language itself.
    var nativeName: String {
        switch self {
        case .indonesian: "Bahasa Indonesia"
        case .english: "English"
        }
    }

    /// Language the app should fall back to when no preference is stored yet.
    static var `default`: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("id") ? .indonesian : .english
    }
}
