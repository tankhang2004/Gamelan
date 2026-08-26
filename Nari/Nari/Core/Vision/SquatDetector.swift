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
    var depthThreshold: CGFloat = 0.16
    /// The player has to come back above this before another squat registers.
    /// Must stay below `depthThreshold`: if it ever rises above, a drop between
    /// the two enters and leaves the squat on alternating frames.
    var releaseThreshold: CGFloat = 0.09
    /// Seconds for the standing baseline to follow a real change in stance.
    var baselineTimeConstant: Double = 2.0
    /// Longer than any real rep — the hold is five seconds plus the trip down
    /// and back up. Staying "squatting" past this means the baseline is wrong,
    /// not that the player is still down, so the baseline is thrown away and
    /// relearned from wherever they are actually standing.
    var maxSquatDuration: Double = 12

    private var baseline: CGFloat?
    private var squatElapsed: Double = 0
    private(set) var isSquatting = false

    /// True only on the frame a squat begins. The cue is scored off this rather
    /// than off `isSquatting`, so a squat left over from the previous rep
    /// cannot satisfy the next cue on its own.
    private(set) var didStartSquat = false

    /// How deep the current squat is, 0 to 1, for the HUD.
    private(set) var depth: Double = 0

    mutating func update(_ snapshot: BodyPoseSnapshot, delta: Double) {
        didStartSquat = false

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
            squatElapsed += delta
            if drop < releaseThreshold {
                isSquatting = false
            } else if squatElapsed >= maxSquatDuration {
                // Relearn from the current stance rather than staying stuck.
                reset()
                baseline = hipHeight
                return
            }
        } else if drop >= depthThreshold {
            isSquatting = true
            didStartSquat = true
            squatElapsed = 0
        }

        // While upright, slowly adapt the baseline. While squatting, freeze it.
        guard !isSquatting else { return }
        let rate = min(delta / baselineTimeConstant, 1)
        baseline = standing + (hipHeight - standing) * rate
    }

    mutating func reset() {
        baseline = nil
        isSquatting = false
        didStartSquat = false
        squatElapsed = 0
        depth = 0
    }
}
