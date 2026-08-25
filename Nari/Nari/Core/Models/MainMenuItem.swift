import Foundation

/// The three round buttons in the top corner of the menu, in display order.
/// PLAY is not one of them — it is the painted pill in the opposite corner.
enum MainMenuItem: String, CaseIterable, Identifiable, Sendable {
    case settings
    case credits
    case scores

    var id: String { rawValue }

    var titleKey: LocalizedKey {
        switch self {
        case .settings: .menuSettings
        case .credits: .menuCredits
        case .scores: .menuScores
        }
    }

    /// SF Symbol shown in the button, matching the Figma icons.
    var symbolName: String {
        switch self {
        case .settings: "gearshape"
        case .credits: "info.circle"
        case .scores: "trophy"
        }
    }
}
