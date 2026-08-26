import Foundation

/// How much of the room the camera takes in, the way the Camera app's 0.5x and
/// 1x buttons work: one sensor, two crops of it.
///
/// The game is normally played with the iPad on the floor a few metres away,
/// where the standard crop frames a child head to toe. On a table the lens is
/// much closer and much higher, and the standard crop cuts their feet off — so
/// the wide setting hands back the full sensor instead of asking the player to
/// find a bigger room.
enum CameraFieldOfView: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Cropped in to roughly what a normal front camera shows. The default —
    /// declared first so it also sits on the left of the toggle, the spot a
    /// player's eye lands on first.
    case standard
    /// The whole sensor. Everything the front camera can see.
    case wide

    var id: String { rawValue }

    /// Horizontal field of view the standard crop aims for, in degrees.
    ///
    /// Front cameras on recent iPads are ultra wide — around 100 degrees across
    /// — which is a lot of room and a lot of barrel distortion for a player who
    /// is already far enough back. This is about what a phone's front camera
    /// gives, and it is only ever a target: if the widest format the device has
    /// is already narrower, there is nothing to crop and both settings match.
    static let standardDegrees: Float = 68

    var labelKey: LocalizedKey {
        switch self {
        case .wide: .cameraFieldWide
        case .standard: .cameraFieldStandard
        }
    }

    /// What the Camera app prints on the button.
    var shortLabel: String {
        switch self {
        case .wide: "0.5×"
        case .standard: "1×"
        }
    }

    var toggled: CameraFieldOfView { self == .wide ? .standard : .wide }
}
