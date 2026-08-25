import Observation

/// Drives the leaderboard popup: fetches the top six of the board, and pins
/// the local player's own row underneath, highlighted, whenever their rank
/// falls outside that top six.
@MainActor
@Observable
final class LeaderboardViewModel {
    enum State {
        case loading
        case signedOut
        case loaded([LeaderboardEntry])
    }

    /// Fixed top rows shown on screen.
    private static let topRows = 6

    private(set) var state: State = .loading

    @ObservationIgnored private let gameCenter: LeaderboardProviding

    init(gameCenter: LeaderboardProviding) {
        self.gameCenter = gameCenter
    }

    func load() async {
        guard gameCenter.isAuthenticated else {
            state = .signedOut
            return
        }

        state = .loading
        let (top, localPlayer) = await gameCenter.loadLeaderboard(topCount: Self.topRows)

        var rows = Array(top.prefix(Self.topRows))
        if let localPlayer, localPlayer.rank > Self.topRows {
            rows.append(localPlayer)
        }
        state = .loaded(rows)
    }
}
