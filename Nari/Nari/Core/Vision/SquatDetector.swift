import CoreGraphics
import Foundation

/// Decides whether the player is squatting (nge'ed).
///
/// Absolute hip height is useless on its own — it moves with how far the player
/// stands from the iPad. What is stable is how far the hips have dropped from
/// where that player stands normally, measured in torso lengths. So the detector
/// keeps a slowly-adapting standing height and compares against that.
///
/// The baseline only rises while the player is upright. It never learns a squat
/// as the new normal, which is what would otherwise happen to a player who takes
/// their time getting back up.
struct SquatDetector {

    /// Drop from standing height, in torso lengths, that counts as a squat.
    var depthThreshold: CGFloat = 0.32
    /// The player has to come back above this before another squat registers.
    var releaseThreshold: CGFloat = 0.18
    /// Seconds for the standing baseline to follow a real change in stance.
    var baselineTimeConstant: Double = 2.0

    private var baseline: CGFloat?
    private(set) var isSquatting = false

    /// How deep the current squat is, 0 to 1, for the HUD.
    private(set) var depth: Double = 0

    mutating func update(_ snapshot: BodyPoseSnapshot, delta: Double) {
        guard let frame = BodyFrame(snapshot: snapshot) else {
            depth = 0
            return
        }

        // Image y grows downwards, so a bigger hip y means lower hips.
        let hipHeight = frame.hipCenter.y
        guard let standing = baseline else {
            baseline = hipHeight
            return
        }

        let drop = (hipHeight - standing) / frame.torsoLength
        depth = Double(max(0, min(1, drop / depthThreshold)))

        if isSquatting {
            if drop < releaseThreshold { isSquatting = false }
        } else if drop >= depthThreshold {
            isSquatting = true
        }

        // Only track the player getting taller, or drifting while upright.
        // Following them downwards would quietly redefine a squat as standing.
        guard !isSquatting else { return }
        let rate = min(delta / baselineTimeConstant, 1)
        baseline = standing + (hipHeight - standing) * rate
    }

    mutating func reset() {
        baseline = nil
        isSquatting = false
        depth = 0
    }
}
