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
    /// The default state: walking with a steady left-right head tilt.
    case ngayog
    /// A squat has been asked for and the window is open.
    case squatCue(remaining: Double)
    /// A freeze has been asked for; the player is getting into the pose.
    case freezeGrace(side: AgemSide, remaining: Double)
    /// The pose locked in and is being held.
    case freezeHold(side: AgemSide, elapsed: Double)
    case gameOver

    var isInterrupt: Bool {
        switch self {
        case .ngayog, .gameOver: false
        case .squatCue, .freezeGrace, .freezeHold: true
        }
    }

    /// The pose the reference card should be showing.
    var cuedSide: AgemSide? {
        switch self {
        case .freezeGrace(let side, _), .freezeHold(let side, _): side
        case .ngayog, .squatCue, .gameOver: nil
        }
    }
}

/// What just happened, so the view layer can flash the right thing and the audio
/// layer can play the right cue. Purely a report — no state lives here.
enum RunEvent: Equatable, Sendable {
    case ngayogCycle
    case squatCued
    case squatHit
    case squatMissed
    case freezeCued(AgemSide)
    case freezeLocked
    case freezeHeldFully
    case freezeBrokenEarly
    case freezeFailed
    case energyLow
    case gameOver(score: Int)
}
