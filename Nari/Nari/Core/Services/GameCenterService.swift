import GameKit
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
    /// Top `count` entries, plus the local player's own entry (which may sit
    /// outside that range) if they are signed in and have a score.
    func loadLeaderboard(topCount: Int) async -> (top: [LeaderboardEntry], localPlayer: LeaderboardEntry?)
}

/// Set once Game Center hands back a sign-in sheet to show. `RootView` reads
/// this to present it, since the service itself has no view to present from.
@MainActor
enum GameCenterPresentation {
    static var pendingViewController: UIViewController?
}

@MainActor
final class GameCenterService: LeaderboardProviding {
    /// Replace with the real leaderboard ID once it exists in App Store Connect.
    static let leaderboardID = "com.yuknari.highscore"

    private(set) var isAuthenticated = false

    /// Nonisolated so `GameCenterService()` can sit as a default parameter
    /// value, which Swift evaluates outside the main actor.
    nonisolated init() {}

    func authenticate() async {
        await withCheckedContinuation { continuation in
            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
                if let viewController {
                    GameCenterPresentation.pendingViewController = viewController
                }
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                continuation.resume()
            }
        }
    }

    func submit(score: Int) async {
        guard isAuthenticated else { return }
        try? await GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [Self.leaderboardID]
        )
    }

    func loadLeaderboard(topCount: Int) async -> (top: [LeaderboardEntry], localPlayer: LeaderboardEntry?) {
        guard isAuthenticated else { return ([], nil) }

        guard let leaderboard = try? await GKLeaderboard.loadLeaderboards(IDs: [Self.leaderboardID]).first else {
            return ([], nil)
        }

        guard let (localEntry, entries, _) = try? await leaderboard.loadEntries(
            for: .global,
            timeScope: .allTime,
            range: NSRange(location: 1, length: topCount)
        ) else {
            return ([], nil)
        }

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

        return (top, localPlayer)
    }
}

/// Always empty, never authenticated — for previews and for platforms where
/// Game Center makes no sense (the simulator can sign in, but tests should not).
final class NoopLeaderboardService: LeaderboardProviding {
    let isAuthenticated = false
    func authenticate() async {}
    func submit(score: Int) async {}
    func loadLeaderboard(topCount: Int) async -> (top: [LeaderboardEntry], localPlayer: LeaderboardEntry?) { ([], nil) }
}
