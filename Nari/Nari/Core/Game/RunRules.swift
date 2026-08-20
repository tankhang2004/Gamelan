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

    /// The GDD gives this as 1 second in the core loop and 2 seconds in the
    /// mechanics table. The longer window is used: a 1-second reaction to an
    /// unannounced cue is close to impossible for the children this is for.
    var squatWindow: Double = 2
    var squatHitEnergy: Double = 5
    var squatHitScore: Int = 5
    var squatMissEnergy: Double = -8

    // MARK: - Agem (freeze interrupt)

    /// Time to get all nine points into the pose before the run ends.
    var freezeGracePeriod: Double = 3
    /// Time the pose has to be held once it locks in.
    var freezeHoldDuration: Double = 7
    var freezeFailEnergy: Double = -20
    var freezeHoldEnergyPerSecond: Double = 3
    /// Points per second while holding, before the energy multiplier. A full
    /// Taksu meter pays the whole 20; a meter at 40% pays 8.
    var freezeHoldScorePerSecond: Double = 20

    // MARK: - Interrupt scheduler

    /// One shared timer, so Squat and Freeze can never fire together.
    var initialInterruptInterval: ClosedRange<Double> = 4...9
    var minimumInterruptInterval: ClosedRange<Double> = 2...5
    /// Chance the shared timer picks Freeze rather than Squat.
    var initialFreezeChance: Double = 0.15
    var maximumFreezeChance: Double = 0.40

    // MARK: - Difficulty ramp

    var rampInterval: Double = 45
    /// Fraction the interrupt interval shrinks by at each ramp step.
    var rampIntervalShrink: Double = 0.10
    /// Percentage points added to the Freeze chance at each ramp step.
    var rampFreezeChanceIncrease: Double = 0.05

    static let `default` = RunRules()
}
