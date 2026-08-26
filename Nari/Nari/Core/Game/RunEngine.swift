import CoreGraphics
import Foundation
import OSLog
import Observation

/// What the body-tracking layer saw this frame, reduced to the three questions
/// the loop actually asks. Keeping the engine behind this struct is what lets
/// the whole game be driven by fake input in a preview or a test.
struct RunInput: Sendable {
    /// A foot landed on this frame — one beat of the march.
    var completedNgayogCycle = false
    /// The player is currently below the squat threshold. Used for holding a
    /// squat, where staying down is the whole task.
    var isSquatting = false
    /// The player dropped into a squat on this frame. Used for answering a
    /// squat cue, which asks for a squat rather than for already being down.
    var squatBegan = false
    /// All nine tracked points are inside the cued pose right now.
    var matchesCuedPose = false
    /// Wrists and ankles in normalized image space — a flower is caught with
    /// whichever reaches it first. Empty when the body cannot be read this
    /// frame.
    var catchPositions: [CGPoint] = []
    /// The hip centre in the same space, so a coin can be placed a walk away
    /// from wherever the player is standing. Nil when the body is not readable.
    var playerCenter: CGPoint?
    /// Frame height over width, so a gap upwards means the same as a gap
    /// sideways when a distance is measured.
    var frameAspect: CGFloat = 0.75

    static let idle = RunInput()
}

/// The core loop.
///
/// One shared timer decides when an interrupt fires and which one it is, so
/// Squat and Freeze can never overlap — the "never at the same time" rule in the
/// design is a property of there being one timer, not a check anywhere in here.
/// Every branch ends by falling back to `ngayog` and testing Taksu.
@MainActor
@Observable
final class RunEngine {

    private(set) var phase: RunPhase = .ngayog
    /// The coins currently on the floor. Only ever non-empty during `ngayog`.
    private(set) var coinField = CoinField()
    private(set) var energy: Double
    private(set) var score: Int = 0
    /// Seconds survived, which drives both the on-screen timer and the ramp.
    private(set) var elapsed: Double = 0
    /// `elapsed` at the moment the run last entered `.ngayog`, so the view
    /// layer can show the march instruction only for the first couple of
    /// seconds back on the floor before handing the banner to the flower hint.
    private(set) var ngayogEnteredAt: Double = 0

    /// 0–1, for whichever bar the current phase wants to draw: the squat window
    /// running out, the grace period running out, or the hold filling up.
    var phaseProgress: Double {
        switch phase {
        case .squatCue(let remaining): 1 - remaining / rules.squatGracePeriod
        case .squatHold(let held): holdTotal > 0 ? held / holdTotal : 0
        case .freezeGrace(_, let remaining): 1 - remaining / rules.freezeGracePeriod
        case .freezeHold(_, let held): holdTotal > 0 ? held / holdTotal : 0
        case .leyakWarning(_, let remaining): 1 - remaining / rules.leyakWarningSeconds
        case .leyakDive(_, let progress): progress
        case .ngayog, .gameOver: 0
        }
    }

    /// Seconds since the run last dropped back into `.ngayog` — zero the
    /// instant it does, climbing while the player is just marching.
    var ngayogPhaseElapsed: Double { elapsed - ngayogEnteredAt }

    var energyFraction: Double { energy / rules.maximumEnergy }
    var isEnergyLow: Bool { energy < Self.lowEnergyThreshold }

    private static let lowEnergyThreshold: Double = 20

    @ObservationIgnored private let rules: RunRules
    /// Seeded rather than system so a run can be replayed exactly in a test or a
    /// preview; the default seed is random, so real play is not repeatable.
    @ObservationIgnored private var generator: SeededGenerator
    @ObservationIgnored private var timeToNextInterrupt: Double = 0
    @ObservationIgnored private var interruptInterval: ClosedRange<Double>
    @ObservationIgnored private var freezeChance: Double
    @ObservationIgnored private var rampsApplied = 0
    /// The score drip during a hold is fractional; whole points are banked from
    /// here so a 7-second hold does not lose a point per second to rounding.
    @ObservationIgnored private var hasWarnedLowEnergy = false
    /// How long the hold in progress runs for. Drawn fresh at every cue, so a
    /// player cannot learn one rhythm and stop watching.
    @ObservationIgnored private var holdTotal: Double = 0

    init(rules: RunRules = .default, seed: UInt64 = .random(in: UInt64.min...UInt64.max)) {
        self.rules = rules
        self.generator = SeededGenerator(seed: seed)
        self.energy = rules.startingEnergy
        self.interruptInterval = rules.initialInterruptInterval
        self.freezeChance = rules.initialFreezeChance
        scheduleNextInterrupt()
        warnIfSquatsAreCrowdedOut()
    }

    /// Says so once, at the top of a run, if the chances are tuned past what
    /// the roll can hold. `interruptCuts` will keep the loop honest either
    /// way, but a clamp nobody is told about is the same silence this guards
    /// against — the point is that a mis-tune is visible while it is being
    /// tuned, not that it is survivable.
    private func warnIfSquatsAreCrowdedOut() {
        let claimed = rules.leyakChance + rules.maximumFreezeChance
        let budget = 1 - rules.minimumSquatChance
        guard claimed > budget else { return }

        Logger.run.warning(
            "Leyak \(self.rules.leyakChance, privacy: .public) + Freeze up to \(self.rules.maximumFreezeChance, privacy: .public) claims \(claimed, privacy: .public) of the interrupt roll, past the \(budget, privacy: .public) left by minimumSquatChance. Freeze will be capped short of its maximum so Squat keeps its share."
        )
    }

    // MARK: - Ticking

    /// Advances the run by one frame. Returns everything that happened, in
    /// order, for the caller to turn into sounds and flashes.
    @discardableResult
    func advance(delta: Double, input: RunInput) -> [RunEvent] {
        guard phase != .gameOver, delta > 0 else { return [] }

        elapsed += delta
        var events: [RunEvent] = []

        applyDifficultyRamp()

        switch phase {
        case .ngayog:
            advanceNgayog(delta: delta, input: input, events: &events)
        case .squatCue(let remaining):
            advanceSquatCue(remaining: remaining, delta: delta, input: input, events: &events)
        case .squatHold(let held):
            advanceSquatHold(held: held, delta: delta, input: input, events: &events)
        case .freezeGrace(let side, let remaining):
            advanceFreezeGrace(side: side, remaining: remaining, delta: delta, input: input, events: &events)
        case .freezeHold(let side, let held):
            advanceFreezeHold(side: side, held: held, delta: delta, input: input, events: &events)
        case .leyakWarning(let column, let remaining):
            advanceLeyakWarning(column: column, remaining: remaining, delta: delta)
        case .leyakDive(let column, let progress):
            advanceLeyakDive(column: column, progress: progress, delta: delta, input: input, events: &events)
        case .gameOver:
            break
        }

        checkLowEnergyWarning(&events)
        checkGameOver(&events)
        return events
    }

    // MARK: - Phases

    private func advanceNgayog(delta: Double, input: RunInput, events: inout [RunEvent]) {
        if input.completedNgayogCycle {
            change(energy: rules.ngayogCycleEnergy)
            score += rules.ngayogCycleScore
            events.append(.ngayogCycle)
        }

        let tick = coinField.advance(
            delta: delta,
            catchers: input.catchPositions,
            player: input.playerCenter,
            frameAspect: input.frameAspect,
            rules: rules,
            generator: &generator
        )
        if tick.didSpawn { events.append(.coinSpawned) }
        for value in tick.collected {
            score += value
            events.append(.coinCollected(value: value))
        }

        timeToNextInterrupt -= delta
        guard timeToNextInterrupt <= 0 else { return }

        // Rolled before the lockouts are checked, so an early Freeze or Leyak
        // is suppressed rather than re-rolled into a squat that was never
        // drawn.
        let cuts = interruptCuts
        let roll = Double.random(in: 0..<1, using: &generator)
        let rolledLeyak = roll < cuts.leyak
        let rolledFreeze = !rolledLeyak && roll < cuts.freeze

        coinField.clear()

        if rolledLeyak, elapsed >= rules.leyakLockout {
            // It falls where the player is standing. A Leyak that spawned at
            // random would mostly miss on its own, which teaches nothing —
            // aiming it is what makes the dodge the whole point.
            //
            // Aimed here rather than when the dive starts, so the flagged
            // column is a promise: stepping out of it during the warning is
            // what saves the player, and it cannot follow them.
            let column = input.playerCenter?.x ?? 0.5
            phase = .leyakWarning(column: column, remaining: rules.leyakWarningSeconds)
            events.append(.leyakCued)
        } else if rolledFreeze, elapsed >= rules.freezeLockout {
            let side = AgemSide.allCases.randomElement(using: &generator) ?? .kanan
            phase = .freezeGrace(side: side, remaining: rules.freezeGracePeriod)
            events.append(.freezeCued(side))
        } else {
            phase = .squatCue(remaining: rules.squatGracePeriod)
            events.append(.squatCued)
        }
    }

    /// The column lit up before anything falls down it. Nothing can be hit
    /// here — this is purely the window the player gets to read where it is
    /// coming and start moving.
    private func advanceLeyakWarning(column: CGFloat, remaining: Double, delta: Double) {
        let left = remaining - delta
        if left <= 0 {
            phase = .leyakDive(column: column, progress: 0)
        } else {
            phase = .leyakWarning(column: column, remaining: left)
        }
    }

    /// The Leyak coming down. Nothing to do but be somewhere else by the time
    /// it arrives — this is the one move that cannot be ridden out in place.
    private func advanceLeyakDive(
        column: CGFloat,
        progress: Double,
        delta: Double,
        input: RunInput,
        events: inout [RunEvent]
    ) {
        let next = progress + delta / rules.leyakDiveSeconds

        // Only lethal once it is actually down among the player, so standing
        // under it at the moment it appears is a warning rather than a death.
        if next >= rules.leyakStrikeStart, let player = input.playerCenter,
           abs(player.x - column) < rules.leyakColumnHalfWidth {
            events.append(.leyakHit)
            energy = 0
            return
        }

        if next >= 1 {
            change(energy: rules.leyakDodgedEnergy)
            score += rules.leyakDodgedScore
            events.append(.leyakDodged)
            returnToNgayog()
        } else {
            phase = .leyakDive(column: column, progress: next)
        }
    }

    private func advanceSquatCue(
        remaining: Double,
        delta: Double,
        input: RunInput,
        events: inout [RunEvent]
    ) {
        if input.squatBegan {
            change(energy: rules.squatHitEnergy)
            score += rules.squatHitScore
            events.append(.squatHit)
            holdTotal = Double.random(in: rules.squatHoldDuration, using: &generator)
            phase = .squatHold(elapsed: 0)
            return
        }

        let left = remaining - delta
        if left <= 0 {
            change(energy: rules.squatMissEnergy)
            events.append(.squatMissed)
            returnToNgayog()
        } else {
            phase = .squatCue(remaining: left)
        }
    }

    /// Down in the nge'ed with the wave coming over. Nothing to do but stay
    /// low: standing early is what the wave is there to punish.
    private func advanceSquatHold(
        held: Double,
        delta: Double,
        input: RunInput,
        events: inout [RunEvent]
    ) {
        guard input.isSquatting else {
            change(energy: rules.squatBreakEnergy)
            events.append(.squatBrokenEarly)
            returnToNgayog()
            return
        }

        let total = held + delta
        if total >= holdTotal {
            change(energy: rules.squatHoldEnergy)
            score += rules.squatHoldScore
            events.append(.squatHeldFully)
            returnToNgayog()
        } else {
            phase = .squatHold(elapsed: total)
        }
    }

    private func advanceFreezeGrace(
        side: AgemSide,
        remaining: Double,
        delta: Double,
        input: RunInput,
        events: inout [RunEvent]
    ) {
        // Read time first: the cue has to be on screen long enough to be read
        // before striking the pose counts, or a player who happened to already
        // be standing in it never sees what they were asked for.
        let shown = rules.freezeGracePeriod - remaining
        if shown >= rules.freezeReadSeconds, input.matchesCuedPose {
            holdTotal = Double.random(in: rules.freezeHoldDuration, using: &generator)
            phase = .freezeHold(side: side, elapsed: 0)
            events.append(.freezeLocked)
            return
        }

        let left = remaining - delta
        if left <= 0 {
            // The heaviest cost in the game, but still only a cost. If it takes
            // the meter to zero the run ends, and `checkGameOver` is what says
            // so — every branch is judged by Taksu, this one included.
            change(energy: rules.freezeFailEnergy)
            events.append(.freezeFailed)
            returnToNgayog()
        } else {
            phase = .freezeGrace(side: side, remaining: left)
        }
    }

    private func advanceFreezeHold(
        side: AgemSide,
        held: Double,
        delta: Double,
        input: RunInput,
        events: inout [RunEvent]
    ) {
        guard input.matchesCuedPose else {
            // Breaking early is not punished, but it pays nothing either: the
            // agem is banked on completion now, not dripped, so that the
            // "GREAT AGEM" banner can state one honest number.
            events.append(.freezeBrokenEarly)
            returnToNgayog()
            return
        }

        let total = held + delta
        if total >= holdTotal {
            change(energy: rules.freezeHoldEnergy)
            score += rules.freezeHoldScore
            events.append(.freezeHeldFully)
            returnToNgayog()
        } else {
            phase = .freezeHold(side: side, elapsed: total)
        }
    }

    private func returnToNgayog() {
        phase = .ngayog
        ngayogEnteredAt = elapsed
        holdTotal = 0
        coinField.clear()
        scheduleNextInterrupt()
    }

    // MARK: - Scheduler and ramp

    private func scheduleNextInterrupt() {
        timeToNextInterrupt = Double.random(in: interruptInterval, using: &generator)
    }

    /// Where the two cuts fall on the 0–1 interrupt roll: below `leyak` is a
    /// Leyak, below `freeze` is a Freeze, and the rest of the line is a squat.
    ///
    /// Both are held inside a budget that leaves `minimumSquatChance` of the
    /// line unclaimed, so the squat band can never be squeezed shut by the two
    /// bands in front of it. Leyak is clamped first because it is rolled
    /// first; with the shipped numbers neither clamp binds, and this only
    /// comes into play if the chances are retuned past what the line can hold.
    private var interruptCuts: (leyak: Double, freeze: Double) {
        let budget = max(0, 1 - rules.minimumSquatChance)
        let leyak = min(rules.leyakChance, budget)
        return (leyak, min(leyak + freezeChance, budget))
    }

    /// Every 45 seconds survived the interval shrinks and Freeze gets likelier,
    /// both stopping at a floor so a long run stays playable rather than
    /// becoming a wall.
    private func applyDifficultyRamp() {
        let due = Int(elapsed / rules.rampInterval)
        guard due > rampsApplied else { return }

        for _ in rampsApplied..<due {
            let shrink = 1 - rules.rampIntervalShrink
            interruptInterval = max(
                interruptInterval.lowerBound * shrink,
                rules.minimumInterruptInterval.lowerBound
            )...max(
                interruptInterval.upperBound * shrink,
                rules.minimumInterruptInterval.upperBound
            )
            freezeChance = min(freezeChance + rules.rampFreezeChanceIncrease, rules.maximumFreezeChance)
        }
        rampsApplied = due
    }

    // MARK: - Taksu

    private func change(energy delta: Double) {
        energy = min(max(energy + delta, 0), rules.maximumEnergy)
        if energy >= Self.lowEnergyThreshold { hasWarnedLowEnergy = false }
    }

    private func checkLowEnergyWarning(_ events: inout [RunEvent]) {
        guard isEnergyLow, energy > 0, !hasWarnedLowEnergy else { return }
        hasWarnedLowEnergy = true
        events.append(.energyLow)
    }

    private func checkGameOver(_ events: inout [RunEvent]) {
        guard energy <= 0, phase != .gameOver else { return }
        phase = .gameOver
        events.append(.gameOver(score: score))
    }
}

private extension Logger {
    static let run = Logger(subsystem: "com.yuknari.Nari", category: "run")
}
