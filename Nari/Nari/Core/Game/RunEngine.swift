import Foundation
import Observation

/// What the body-tracking layer saw this frame, reduced to the three questions
/// the loop actually asks. Keeping the engine behind this struct is what lets
/// the whole game be driven by fake input in a preview or a test.
struct RunInput: Sendable {
    /// A full left-right head tilt finished on this frame.
    var completedNgayogCycle = false
    /// The player is currently below the squat threshold.
    var isSquatting = false
    /// All nine tracked points are inside the cued pose right now.
    var matchesCuedPose = false

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
    private(set) var energy: Double
    private(set) var score: Int = 0
    /// Seconds survived, which drives both the on-screen timer and the ramp.
    private(set) var elapsed: Double = 0

    /// 0–1, for whichever bar the current phase wants to draw: the squat window
    /// running out, the grace period running out, or the hold filling up.
    var phaseProgress: Double {
        switch phase {
        case .squatCue(let remaining): 1 - remaining / rules.squatWindow
        case .freezeGrace(_, let remaining): 1 - remaining / rules.freezeGracePeriod
        case .freezeHold(_, let held): held / rules.freezeHoldDuration
        case .ngayog, .gameOver: 0
        }
    }

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
    @ObservationIgnored private var scoreFraction: Double = 0
    @ObservationIgnored private var hasWarnedLowEnergy = false

    init(rules: RunRules = .default, seed: UInt64 = .random(in: UInt64.min...UInt64.max)) {
        self.rules = rules
        self.generator = SeededGenerator(seed: seed)
        self.energy = rules.startingEnergy
        self.interruptInterval = rules.initialInterruptInterval
        self.freezeChance = rules.initialFreezeChance
        scheduleNextInterrupt()
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
        case .freezeGrace(let side, let remaining):
            advanceFreezeGrace(side: side, remaining: remaining, delta: delta, input: input, events: &events)
        case .freezeHold(let side, let held):
            advanceFreezeHold(side: side, held: held, delta: delta, input: input, events: &events)
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

        timeToNextInterrupt -= delta
        guard timeToNextInterrupt <= 0 else { return }

        if Double.random(in: 0..<1, using: &generator) < freezeChance {
            let side = AgemSide.allCases.randomElement(using: &generator) ?? .kanan
            phase = .freezeGrace(side: side, remaining: rules.freezeGracePeriod)
            events.append(.freezeCued(side))
        } else {
            phase = .squatCue(remaining: rules.squatWindow)
            events.append(.squatCued)
        }
    }

    private func advanceSquatCue(
        remaining: Double,
        delta: Double,
        input: RunInput,
        events: inout [RunEvent]
    ) {
        if input.isSquatting {
            change(energy: rules.squatHitEnergy)
            score += rules.squatHitScore
            events.append(.squatHit)
            returnToNgayog()
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

    private func advanceFreezeGrace(
        side: AgemSide,
        remaining: Double,
        delta: Double,
        input: RunInput,
        events: inout [RunEvent]
    ) {
        if input.matchesCuedPose {
            phase = .freezeHold(side: side, elapsed: 0)
            scoreFraction = 0
            events.append(.freezeLocked)
            return
        }

        let left = remaining - delta
        if left <= 0 {
            // The one failure in the game that ends the run outright.
            change(energy: rules.freezeFailEnergy)
            events.append(.freezeFailed)
            events.append(.gameOver(score: score))
            phase = .gameOver
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
            // Breaking early is not punished — the drip simply stops, and
            // everything banked so far is kept.
            events.append(.freezeBrokenEarly)
            returnToNgayog()
            return
        }

        change(energy: rules.freezeHoldEnergyPerSecond * delta)
        // A fuller meter pays more per second, so holding Taksu high is worth
        // something beyond survival.
        scoreFraction += rules.freezeHoldScorePerSecond * energyFraction * delta
        let whole = scoreFraction.rounded(.down)
        score += Int(whole)
        scoreFraction -= whole

        let total = held + delta
        if total >= rules.freezeHoldDuration {
            events.append(.freezeHeldFully)
            returnToNgayog()
        } else {
            phase = .freezeHold(side: side, elapsed: total)
        }
    }

    private func returnToNgayog() {
        phase = .ngayog
        scoreFraction = 0
        scheduleNextInterrupt()
    }

    // MARK: - Scheduler and ramp

    private func scheduleNextInterrupt() {
        timeToNextInterrupt = Double.random(in: interruptInterval, using: &generator)
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
