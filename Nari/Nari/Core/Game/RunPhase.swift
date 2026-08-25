import Foundation

/// Which of the two mirrored held poses the Freeze cue asked for.
enum AgemSide: String, CaseIterable, Sendable {
    case kanan
    case kiri

    var poseID: String { "agem-\(rawValue)" }

    var mirrored: AgemSide { self == .kanan ? .kiri : .kanan }
}

/// Where a run is inside the core loop.
///
/// Everything funnels back through `ngayog`, and every branch ends by checking
/// Taksu — that check is what makes four flows one loop.
enum RunPhase: Equatable, Sendable {
    /// The default state: walking with a steady left-right head tilt, and the
    /// only phase in which coins are on the floor.
    case ngayog
    /// A squat has been asked for and the window is open.
    case squatCue(remaining: Double)
    /// The squat landed and now has to be held while the wave passes over.
    case squatHold(elapsed: Double)
    /// A freeze has been asked for; the player is getting into the pose.
    case freezeGrace(side: AgemSide, remaining: Double)
    /// The pose locked in and is being held.
    case freezeHold(side: AgemSide, elapsed: Double)
    /// The column a Leyak is about to come down is lit up, but nothing is
    /// falling yet. `column` is where it will fall, in normalized image x;
    /// `remaining` counts down to the dive.
    case leyakWarning(column: CGFloat, remaining: Double)
    /// A Leyak is diving down the room and has to be side-stepped. `column` is
    /// where it will fall, in normalized image x; `progress` runs 0 to 1 as it
    /// comes down.
    case leyakDive(column: CGFloat, progress: Double)
    case gameOver

    var isInterrupt: Bool {
        switch self {
        case .ngayog, .gameOver: false
        case .squatCue, .squatHold, .freezeGrace, .freezeHold, .leyakWarning, .leyakDive: true
        }
    }

    /// The pose the reference card should be showing.
    var cuedSide: AgemSide? {
        switch self {
        case .freezeGrace(let side, _), .freezeHold(let side, _): side
        case .ngayog, .squatCue, .squatHold, .leyakWarning, .leyakDive, .gameOver: nil
        }
    }

    /// Where a Leyak is aimed, while one is either being flagged or falling.
    var leyakColumn: CGFloat? {
        switch self {
        case .leyakWarning(let column, _), .leyakDive(let column, _): column
        default: nil
        }
    }
}

/// What just happened, so the view layer can flash the right thing and the audio
/// layer can play the right cue. Purely a report — no state lives here.
enum RunEvent: Equatable, Sendable {
    case ngayogCycle
    /// A Leyak started its dive.
    case leyakCued
    /// It went past without touching the player.
    case leyakDodged
    /// It landed on them. There is no recovering from this one.
    case leyakHit
    /// A frangipani opened somewhere in the room.
    case coinSpawned
    /// A frangipani was picked, worth this many points at the size it was
    /// caught — the longer it had been wilting, the less this is.
    case coinCollected(value: Int)
    case squatCued
    case squatHit
    case squatMissed
    /// Stood up before the wave had passed.
    case squatBrokenEarly
    case squatHeldFully
    case freezeCued(AgemSide)
    case freezeLocked
    case freezeHeldFully
    case freezeBrokenEarly
    case freezeFailed
    case energyLow
    case gameOver(score: Int)
}
