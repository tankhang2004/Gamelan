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

    // MARK: - Ngayog (marching in place, the default move)

    /// Paid per footfall while marching.
    ///
    /// Marching is optional: it scores nothing on its own, so a player can
    /// stand still and still pick flowers. What it buys is Taksu — the meter
    /// that keeps the run alive — which makes it worth doing without making
    /// it the thing being scored.
    ///
    /// Halved from the old head-tilt reward because a march lands roughly
    /// twice as often as a full left-right tilt did, so the energy per second
    /// stays where it was.
    var ngayogCycleEnergy: Double = 1
    var ngayogCycleScore: Int = 0

    /// How long the march reference card stays on screen at the start of a
    /// run. After this the card slot belongs to the interrupts alone, and the
    /// march is carried by the prompt text — it is the resting state, so a
    /// card that never changes is just something in front of the camera.
    var marchCardSeconds: Double = 8

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

    // MARK: - Frangipanis (gathered during the march)

    /// How a flower wilts across its lifetime, from just-spawned to gone.
    ///
    /// Picked immediately it is full size and pays full value; left to the
    /// last moment it is a third of the size and pays a third. This is the
    /// "grab it fast" pressure — nothing else in the loop rewards urgency.
    var coinWiltScale: ClosedRange<CGFloat> = 0.34...1.0
    var coinWiltValue: ClosedRange<CGFloat> = 0.30...1.0


    /// How many sizes of coin there are. Tier 1 is the smallest and sits
    /// closest in; tier 10 is the biggest, sits furthest out, and pays most.
    var coinTierCount: Int = 10
    /// Value of the smallest coin, and the step between one tier and the next,
    /// so every coin on screen is worth a round multiple of ten.
    var coinValueStep: Int = 10
    /// Seconds a coin stays out, for the nearest and the furthest.
    ///
    /// The design asks for four seconds, which is right for a coin at arm's
    /// length. Now that the far ones are a walk away, holding every coin to
    /// four would make the best of them impossible rather than hard, so the
    /// time out scales with the distance. Set both ends to 4 to flatten it.
    var coinLifetime: ClosedRange<Double> = 4...7
    var coinSpawnInterval: ClosedRange<Double> = 1.2...2.2
    var maximumCoinsOnScreen: Int = 3
    /// How far a coin may spawn from the player, in frame widths.
    ///
    /// The near end is a lean, the far end is a walk across the room. Nothing
    /// spawns inside the near end, so every coin costs the player some
    /// movement rather than being collected by standing still and waving.
    ///
    /// The far end is the centre-to-corner distance of the play area below, so
    /// the top tier is reachable by a player standing in the middle of it. Set
    /// it beyond that and the best coins simply never get drawn.
    var coinPlayerDistanceRange: ClosedRange<CGFloat> = 0.16...0.42
    /// The part of the frame coins may use, in normalized image coordinates.
    ///
    /// Not the whole frame, because the HUD is in the way: the Taksu meter runs
    /// down the left, the move card down the right, the score and clock across
    /// the top. A coin behind any of those is one the player never sees, so the
    /// corners worth chasing are the corners of this box rather than of the
    /// picture.
    /// Horizontal bounds are dependable: a 4:3 capture filling a wider screen
    /// is scaled by width, so image x and screen x line up. Vertical bounds
    /// drift by a few percent with the screen's shape, hence the loose margin
    /// at the top rather than a value tuned to one iPad.
    var coinPlayArea = CGRect(x: 0.12, y: 0.22, width: 0.68, height: 0.70)
    /// Drawn radius of the smallest and largest coin, in frame widths.
    var coinRadiusRange: ClosedRange<CGFloat> = 0.030...0.070
    /// Clear space kept between two coins, so they never overlap on screen.
    var coinMinimumSeparation: CGFloat = 0.04

    // MARK: - Footwork

    /// How far an ankle has to lift off the ground, in torso lengths, before
    /// coming back down counts as a step rather than as a wobble.
    ///
    /// Low on purpose. Ngayog is a small shuffling walk, not a march, and a
    /// threshold set for a clear knee-high step quietly ignores half of what a
    /// child actually does. Raise it if sparks start appearing while a player
    /// stands still.
    var stepLiftThreshold: CGFloat = 0.045
    /// How close to the ground it has to return to land.
    var stepPlantThreshold: CGFloat = 0.018
    /// Shortest gap between two steps on the same foot, in seconds.
    var stepDebounce: Double = 0.16
    /// How long a spark burns where a foot landed.
    var stepSparkSeconds: Double = 0.55

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
