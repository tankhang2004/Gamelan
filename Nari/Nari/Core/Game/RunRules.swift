import CoreGraphics
import Foundation

/// Every tunable number from the game design document, in one place.
///
/// Nothing in the loop hard-codes a duration or a reward — the whole feel of a
/// run can be retuned here without touching the state machine or the views.
struct RunRules: Sendable {

    // MARK: - Taksu (energy)

    var startingEnergy: Double = 50
    var maximumEnergy: Double = 100

    // MARK: - Ngayog (the default walk)

    /// One full left-right head tilt.
    var ngayogCycleEnergy: Double = 2
    var ngayogCycleScore: Int = 5

    // MARK: - Nge'ed (squat interrupt)

    /// Time to get down into the squat before the cue is lost.
    var squatGracePeriod: Double = 4
    var squatHitEnergy: Double = 5
    var squatHitScore: Int = 5
    var squatMissEnergy: Double = -8

    /// Seconds the squat has to be held once it locks in, while the wave passes
    /// overhead.
    ///
    /// A range rather than a number so the hold can differ from cue to cue;
    /// both ends sit at the design's starting value, so widening it is a
    /// one-line change here.
    var squatHoldDuration: ClosedRange<Double> = 5...5
    /// Paid once for riding out the whole wave.
    var squatHoldScore: Int = 15
    /// Standing up into the wave. Costs the same as never squatting at all.
    var squatBreakEnergy: Double = -8

    // MARK: - Agem (freeze interrupt)

    /// Time to get all nine points into the pose before the cue is lost.
    var freezeGracePeriod: Double = 10
    /// Time the pose has to be held once it locks in. A range for the same
    /// reason as `squatHoldDuration`.
    var freezeHoldDuration: ClosedRange<Double> = 5...5

    /// Missing a Freeze costs a fifth of the meter and nothing else.
    ///
    /// The GDD also ends the round outright here, which makes this number
    /// unobservable — the player never sees the meter move. It also makes
    /// Freeze the only real way to lose, because ngayog out-earns missed squats
    /// until the ramp has been running for minutes, so the document's own
    /// stated lose condition (Taksu reaching 0%) almost never fires. Dropping
    /// the instant end makes the penalty mean something and puts the run back
    /// on the meter.
    var freezeFailEnergy: Double = -20
    var freezeHoldEnergyPerSecond: Double = 3
    /// Points per second while holding, before the energy multiplier. A full
    /// Taksu meter pays the whole 20; a meter at 40% pays 8.
    var freezeHoldScorePerSecond: Double = 20

    // MARK: - Coins (gathered during the walk)

    /// How many sizes of coin there are. Tier 1 is the smallest and sits
    /// closest in; tier 10 is the biggest, sits furthest out, and pays most.
    var coinTierCount: Int = 10
    /// Value of the smallest coin, and the step between one tier and the next,
    /// so every coin on screen is worth a round multiple of ten.
    var coinValueStep: Int = 10
    /// Seconds a coin stays out before it fades.
    var coinLifetime: Double = 4
    var coinSpawnInterval: ClosedRange<Double> = 1.2...2.2
    var maximumCoinsOnScreen: Int = 3
    /// Distance from the hip centre, in torso lengths, for the smallest and the
    /// largest coin. The far end sits at the edge of a child's reach, so the
    /// coins that pay best are the ones worth stretching for.
    var coinDistanceRange: ClosedRange<CGFloat> = 0.6...1.5
    /// Drawn radius of the smallest and largest coin, in torso lengths.
    var coinRadiusRange: ClosedRange<CGFloat> = 0.16...0.42
    /// Clear space kept between two coins, so they never overlap on screen.
    var coinMinimumSeparation: CGFloat = 0.25

    // MARK: - Interrupt scheduler

    /// One shared timer, so Squat and Freeze can never fire together.
    var initialInterruptInterval: ClosedRange<Double> = 4...9
    var minimumInterruptInterval: ClosedRange<Double> = 2...5
    /// Chance the shared timer picks Freeze rather than Squat.
    var initialFreezeChance: Double = 0.15
    var maximumFreezeChance: Double = 0.40

    /// No Freeze can be cued this early into a run.
    ///
    /// The first interrupt can arrive at 4 seconds, so without this a player
    /// could meet the hardest move in the game before they had found their
    /// rhythm — losing a fifth of the meter to something they had no chance to
    /// prepare for. Squats still fire in this window.
    var freezeLockout: Double = 10

    // MARK: - Difficulty ramp

    var rampInterval: Double = 45
    /// Fraction the interrupt interval shrinks by at each ramp step.
    var rampIntervalShrink: Double = 0.10
    /// Percentage points added to the Freeze chance at each ramp step.
    var rampFreezeChanceIncrease: Double = 0.05

    static let `default` = RunRules()
}
