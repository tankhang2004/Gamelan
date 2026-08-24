import CoreGraphics
import Foundation

/// One foot landing, for the view to strike a spark at.
struct Step: Sendable {
    let foot: BodyJoint
    /// Where the ankle was when it landed, in normalized image space.
    let position: CGPoint
}

/// Watches the ankles for a foot that lifted and came back down.
///
/// Each foot is measured against *the other one* — how far it sits above
/// whichever ankle is currently lower — in torso lengths. Every other reference
/// gets something wrong:
///
/// - Against the picture: walk away from the iPad and every joint slides up the
///   frame together, so a planted foot looks lifted and the detector jams.
/// - Against the hips: a nge'ed brings the hips down onto stationary feet,
///   which reads as both feet rising at once and sparks a squat as two steps.
///
/// The supporting foot cannot move relative to itself, so it can never arm, and
/// a squat moves both feet together relative to the hips but not relative to
/// each other. What is left is a foot leaving the floor, which is the thing
/// worth drawing.
struct StepDetector {
    private struct Foot {
        /// Where this foot rests relative to the supporting one. Rarely zero:
        /// a foot placed forward sits lower in the picture than one behind it.
        var floor: CGFloat?
        var isLifted = false
        var secondsLifted: Double = 0
        var secondsSinceStep: Double = .greatestFiniteMagnitude
    }

    /// A foot held up longer than this is standing, not stepping. Disarmed
    /// without a spark, so one odd moment cannot swallow the steps that follow.
    private static let maximumLiftSeconds: Double = 1.4

    private var feet: [BodyJoint: Foot] = [:]

    /// Feeds one frame in and returns whichever feet landed on it.
    mutating func update(
        _ snapshot: BodyPoseSnapshot,
        delta: Double,
        rules: RunRules
    ) -> [Step] {
        guard let frame = BodyFrame(snapshot: snapshot),
              let left = snapshot.position(of: .leftAnkle),
              let right = snapshot.position(of: .rightAnkle)
        else { return [] }

        // Image y grows downwards, so the larger value is the foot on the floor.
        let supporting = max(left.y, right.y)
        var landed: [Step] = []

        for (joint, position) in [(BodyJoint.leftAnkle, left), (.rightAnkle, right)] {
            var foot = feet[joint] ?? Foot()
            foot.secondsSinceStep += delta

            let height = (supporting - position.y) / frame.torsoLength

            guard let floor = foot.floor else {
                foot.floor = height
                feet[joint] = foot
                continue
            }

            let lift = height - floor

            if foot.isLifted {
                foot.secondsLifted += delta

                if lift <= rules.stepPlantThreshold {
                    foot.isLifted = false
                    foot.secondsLifted = 0
                    if foot.secondsSinceStep >= rules.stepDebounce {
                        foot.secondsSinceStep = 0
                        landed.append(Step(foot: joint, position: position))
                    }
                } else if foot.secondsLifted >= Self.maximumLiftSeconds {
                    foot.isLifted = false
                    foot.secondsLifted = 0
                    foot.floor = height
                }
            } else if lift >= rules.stepLiftThreshold {
                foot.isLifted = true
                foot.secondsLifted = 0
            }

            // A foot that settles lower than its known resting place takes the
            // new value at once; otherwise the resting place drifts up slowly,
            // so a change of stance is absorbed within a second or so either way.
            if let current = foot.floor {
                if height < current {
                    foot.floor = height
                } else {
                    foot.floor = current + (height - current) * min(delta / 1.2, 1)
                }
            }

            feet[joint] = foot
        }

        return landed
    }

    mutating func reset() {
        feet.removeAll()
    }
}
