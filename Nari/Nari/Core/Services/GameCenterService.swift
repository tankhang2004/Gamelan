import GameKit
import OSLog
import UIKit

/// One row of the leaderboard, already merged with whether it is the person
/// holding the iPad right now.
struct LeaderboardEntry: Identifiable, Equatable, Sendable {
    let id: String
    let rank: Int
    let displayName: String
    let score: Int
    let isLocalPlayer: Bool
}

/// Why a board came back with no rows. An empty board and a board that never
/// loaded look identical to the player unless they are told apart, so the
/// reason travels with the result instead of collapsing into an empty array.
enum LeaderboardUnavailableReason: Equatable, Sendable {
    /// Nobody is signed in to Game Center on this device.
    case signedOut
    /// Signed in, but App Store Connect has no leaderboard under our ID —
    /// almost always because it has not been created there yet.
    case notConfigured
    /// Signed in and configured, but the fetch itself failed: offline, or
    /// Game Center having a bad day.
    case loadFailed
}

/// What one leaderboard fetch produced. `.entries` with an empty `top` is a
/// real, genuinely empty board — distinct from every `.unavailable` case.
enum LeaderboardResult: Equatable, Sendable {
    case entries(top: [LeaderboardEntry], localPlayer: LeaderboardEntry?)
    case unavailable(LeaderboardUnavailableReason)
}

/// Talks to Game Center for the global leaderboard. Behind a protocol so the
/// menu can be previewed and tested without a signed-in player.
///
/// Main-actor bound because every caller is a view or a view model, and
/// `GKLocalPlayer` expects to be driven from the main thread anyway.
@MainActor
protocol LeaderboardProviding: AnyObject {
    var isAuthenticated: Bool { get }
    func authenticate() async
    func submit(score: Int) async
    /// Top `topCount` entries, plus the local player's own entry (which may sit
    /// outside that range) if they are signed in and have a score.
    func loadLeaderboard(topCount: Int) async -> LeaderboardResult
}

/// Set once Game Center hands back a sign-in sheet to show. `RootView` reads
/// this to present it, since the service itself has no view to present from.
@MainActor
enum GameCenterPresentation {
    static var pendingViewController: UIViewController?
}

@MainActor
final class GameCenterService: LeaderboardProviding {
    /// Must match a leaderboard on this app's App Store Connect record. Until
    /// one exists there, every load comes back `.notConfigured` — see the
    /// leaderboard section of the README for the setup steps.
    static let leaderboardID = "com.ntkl.Nari.highscore"

    private static let log = Logger(subsystem: "com.ntkl.Nari", category: "GameCenter")

    /// Asked of GameKit every time rather than cached. The sign-in sheet
    /// finishes long after `authenticate()` has returned, and a player can sign
    /// out from Settings mid-session, so a stored copy goes stale both ways —
    /// which is what made the board claim "sign in" to signed-in players.
    var isAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }

    /// GameKit re-invokes `authenticateHandler` on every later sign-in change,
    /// so the continuation is cleared after the first call: resuming a checked
    /// continuation twice traps the process.
    private var pendingAuthentication: CheckedContinuation<Void, Never>?
    private var hasStartedAuthenticating = false

    /// Nonisolated so `GameCenterService()` can sit as a default parameter
    /// value, which Swift evaluates outside the main actor.
    nonisolated init() {}

    func authenticate() async {
        // Installing a second handler would re-trigger the whole sign-in flow.
        guard !hasStartedAuthenticating else { return }
        hasStartedAuthenticating = true

        await withCheckedContinuation { continuation in
            pendingAuthentication = continuation

            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                // GameKit documents this handler as main-thread.
                MainActor.assumeIsolated {
                    if let viewController {
                        GameCenterPresentation.pendingViewController = viewController
                    }
                    if let error {
                        Self.log.error("Sign-in failed: \(error.localizedDescription, privacy: .public)")
                    }
                    // Fires on the first call only; later sign-in changes land
                    // here too and must not resume anything.
                    self?.pendingAuthentication?.resume()
                    self?.pendingAuthentication = nil
                }
            }
        }
    }

    func submit(score: Int) async {
        guard isAuthenticated else {
            Self.log.notice("Score \(score) not submitted: no player signed in.")
            return
        }

        do {
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [Self.leaderboardID]
            )
        } catch {
            // Swallowed for the player — a failed submit must not interrupt the
            // game-over screen — but logged, because a missing App Store Connect
            // leaderboard shows up here first.
            Self.log.error("Score \(score) rejected: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadLeaderboard(topCount: Int) async -> LeaderboardResult {
        guard isAuthenticated else { return .unavailable(.signedOut) }

        // GameKit rejects an empty range outright.
        let count = max(1, topCount)

        let leaderboard: GKLeaderboard?
        do {
            leaderboard = try await GKLeaderboard.loadLeaderboards(IDs: [Self.leaderboardID]).first
        } catch {
            Self.log.error("Leaderboard lookup failed: \(error.localizedDescription, privacy: .public)")
            return .unavailable(.loadFailed)
        }

        // A clean response with nothing in it means the ID is not on the App
        // Store Connect record, which is a different problem from a failed call.
        guard let leaderboard else {
            Self.log.error("No leaderboard with ID \(Self.leaderboardID, privacy: .public) in App Store Connect.")
            return .unavailable(.notConfigured)
        }

        do {
            let (localEntry, entries, _) = try await leaderboard.loadEntries(
                for: .global,
                timeScope: .allTime,
                range: NSRange(location: 1, length: count)
            )

            let localID = GKLocalPlayer.local.gamePlayerID
            let top = entries.map { entry in
                LeaderboardEntry(
                    id: entry.player.gamePlayerID,
                    rank: entry.rank,
                    displayName: entry.player.displayName,
                    score: entry.score,
                    isLocalPlayer: entry.player.gamePlayerID == localID
                )
            }

            let localPlayer = localEntry.map { entry in
                LeaderboardEntry(
                    id: entry.player.gamePlayerID,
                    rank: entry.rank,
                    displayName: entry.player.displayName,
                    score: entry.score,
                    isLocalPlayer: true
                )
            }

            return .entries(top: top, localPlayer: localPlayer)
        } catch {
            Self.log.error("Leaderboard entries failed: \(error.localizedDescription, privacy: .public)")
            return .unavailable(.loadFailed)
        }
    }
}

/// Always empty, never authenticated — for previews and for platforms where
/// Game Center makes no sense (the simulator can sign in, but tests should not).
final class NoopLeaderboardService: LeaderboardProviding {
    let isAuthenticated = false
    func authenticate() async {}
    func submit(score: Int) async {}
    func loadLeaderboard(topCount: Int) async -> LeaderboardResult { .unavailable(.signedOut) }
}
