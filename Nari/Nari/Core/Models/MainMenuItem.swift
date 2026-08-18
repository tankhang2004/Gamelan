import Foundation

/// The entries in the menu column, in display order.
enum MainMenuItem: String, CaseIterable, Identifiable, Sendable {
    case play
    case settings
    case credits

    var id: String { rawValue }

    var titleKey: LocalizedKey {
        switch self {
        case .play: .menuPlay
        case .settings: .menuSettings
        case .credits: .menuCredits
        }
    }

    /// `play` is the hero action and is rendered larger than the rest.
    var emphasis: Emphasis {
        self == .play ? .primary : .secondary
    }

    /// SF Symbol shown next to the label until custom icon art arrives.
    var symbolName: String {
        switch self {
        case .play: "play.fill"
        case .settings: "slider.horizontal.3"
        case .credits: "heart.text.square"
        }
    }

    enum Emphasis: Sendable {
        case primary
        case secondary
    }
}
