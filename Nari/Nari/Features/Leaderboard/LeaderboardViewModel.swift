import Observation

/// Drives the leaderboard popup: fetches the top six of the board, and pins
/// the local player's own row underneath, highlighted, whenever their rank
/// falls outside that top six.
@MainActor
@Observable
final class LeaderboardViewModel {
    enum State: Equatable {
        case loading
        /// The board could not be read. Carries why, so the popup can tell a
        /// signed-out player apart from a dropped connection.
        case unavailable(LeaderboardUnavailableReason)
        /// A board that loaded. Empty means genuinely nobody has scored yet.
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
        state = .loading

        switch await gameCenter.loadLeaderboard(topCount: Self.topRows) {
        case .entries(let top, let localPlayer):
            var rows = Array(top.prefix(Self.topRows))
            // Only pinned when they fall outside the top rows; inside them they
            // are already on screen, and appending would duplicate the row ID.
            if let localPlayer, localPlayer.rank > Self.topRows {
                rows.append(localPlayer)
            }
            state = .loaded(rows)

        case .unavailable(let reason):
            state = .unavailable(reason)
        }
    }
}
