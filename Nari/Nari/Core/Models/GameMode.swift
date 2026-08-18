import Foundation

/// How a session was started from the main menu. Only one mode exists today;
/// the type stays so more can be added without reshaping the router.
enum GameMode: String, Identifiable, Hashable, Sendable {
    /// The scored motion-tracking session.
    case play

    var id: String { rawValue }
}
