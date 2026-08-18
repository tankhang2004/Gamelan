import Foundation

/// Position of the two stage curtain panels.
enum CurtainPhase: Sendable {
    /// Panels swung aside, stage visible. Used before the menu settles in and
    /// again once the player commits to a session.
    case open
    /// Panels meeting in the middle, acting as the menu backdrop.
    case closed

    var isOpen: Bool { self == .open }
}
