import CoreGraphics
import Foundation

/// Counts full left-right head tilts, the walking rhythm the whole run is built
/// on top of.
///
/// The tilt is measured as how far the nose sits to one side of the shoulder
/// centre, in torso lengths, so it does not matter how close the player is to
/// the camera or how tall they are. A cycle counts once the player has reached
/// both extremes since the last one — reaching the same side twice in a row is
/// one swing, not two.
struct NgayogDetector {

    /// Lateral nose offset, in torso lengths, that counts as tilted.
    var tiltThreshold: CGFloat = 0.18
    /// The head has to come back inside this before another extreme registers,
    /// so a head parked on the boundary does not rattle off cycles.
    var neutralThreshold: CGFloat = 0.07

    private enum Side: Hashable { case left, right }

    private var current: Side?
    private var visited: Set<Side> = []

    /// How far the head is currently tilted, -1 to 1, for the HUD to show the
    /// rhythm back to the player.
    private(set) var tilt: Double = 0

    /// Feeds one frame in. Returns true on the frame a full cycle completes.
    mutating func update(_ snapshot: BodyPoseSnapshot) -> Bool {
        guard let frame = BodyFrame(snapshot: snapshot),
              let nose = snapshot.position(of: .nose)
        else {
            tilt = 0
            return false
        }

        let offset = (nose.x - frame.shoulderCenter.x) / frame.torsoLength
        tilt = Double(max(-1, min(1, offset / tiltThreshold)))

        if abs(offset) < neutralThreshold {
            current = nil
            return false
        }

        guard abs(offset) >= tiltThreshold else { return false }

        let side: Side = offset < 0 ? .left : .right
        guard side != current else { return false }
        current = side

        visited.insert(side)
        guard visited.count == 2 else { return false }

        visited = []
        return true
    }

    mutating func reset() {
        current = nil
        visited = []
        tilt = 0
    }
}
