import SwiftUI

/// The world leaderboard, pulled from Game Center: the top of the board, with
/// the local player's own row pinned to the bottom, highlighted, whenever
/// they fall outside it.
struct LeaderboardPopupView: View {
    @State var viewModel: LeaderboardViewModel
    let onClose: () -> Void

    @Environment(\.strings) private var strings

    private let rowHeight: CGFloat = 44

    private let columns = [
        GridItem(.fixed(70), spacing: 16, alignment: .leading),
        GridItem(.flexible(), spacing: 16, alignment: .center),
        GridItem(.fixed(100), spacing: 0, alignment: .trailing),
    ]

    var body: some View {
        PopupCard(title: strings[.scoresTitle], onClose: onClose) {
            content
                .task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)

        case .unavailable(let reason):
            message(text(for: reason), symbol: symbol(for: reason), canRetry: reason != .notConfigured)

        case .loaded(let rows) where rows.isEmpty:
            message(strings[.scoresEmpty], symbol: "trophy")

        case .loaded(let rows):
            board(rows)
        }
    }

    private func message(_ text: String, symbol: String, canRetry: Bool = false) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
            Text(text)
                .font(Theme.Fonts.body(19))
                .multilineTextAlignment(.center)
                // Without this the popup's fixed height squeezes the label back
                // to one line and truncates the rest.
                .fixedSize(horizontal: false, vertical: true)

            // Offered only where trying again can change the answer: a player
            // who signs in from Settings, or a connection that comes back.
            if canRetry {
                Button(strings[.scoresRetry]) {
                    Task { await viewModel.load() }
                }
                .buttonStyle(PopupActionButtonStyle())
                .padding(.top, 14)
            }
        }
        .foregroundStyle(Theme.Palette.ink.opacity(0.55))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private func text(for reason: LeaderboardUnavailableReason) -> String {
        switch reason {
        case .signedOut: strings[.scoresSignInRequired]
        case .notConfigured: strings[.scoresNotConfigured]
        case .loadFailed: strings[.scoresLoadFailed]
        }
    }

    private func symbol(for reason: LeaderboardUnavailableReason) -> String {
        switch reason {
        case .signedOut: "person.crop.circle.badge.exclamationmark"
        case .notConfigured: "trophy"
        case .loadFailed: "wifi.exclamationmark"
        }
    }

    private func board(_ rows: [LeaderboardEntry]) -> some View {
        VStack(spacing: 0) {
            columnHeader

            // Only the rows scroll, so the column titles stay put and the
            // pinned local-player row stays reachable: iPhone landscape fits
            // about five of the seven rows a full board can hold.
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(rows) { entry in
                        row(entry)
                    }
                }
                .padding(.top, 16)
                .padding(.trailing, 6)
            }
            // No fade mask here, unlike the credits: these rows are discrete,
            // so a half-cut row already reads as "there is more", while a fade
            // would dim the last row on iPad where the whole board fits.
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var columnHeader: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns) {
                Text("RANK")
                Text("USERNAME")
                Text("SCORE")
            }
            .font(Theme.Fonts.label(24))
            .foregroundStyle(Theme.Palette.ink.opacity(0.8))

            Rectangle()
                .fill(Theme.Palette.ink.opacity(0.7))
                .frame(height: 2)
        }
    }

    private func row(_ entry: LeaderboardEntry) -> some View {
        LazyVGrid(columns: columns) {
            rankMark(entry.rank)

            Text(entry.isLocalPlayer ? strings[.scoresYou].uppercased() : entry.displayName)
                .font(Theme.Fonts.label(20))
                .lineLimit(1)

            Text("\(entry.score)")
                .font(Theme.Fonts.readout(20))
        }
        .frame(height: rowHeight)
        .foregroundStyle(entry.isLocalPlayer ? .white : Theme.Palette.ink)
        .padding(.horizontal, entry.isLocalPlayer ? 18 : 4)
        .padding(.vertical, entry.isLocalPlayer ? 8 : 0)
        .background(
            Group {
                if entry.isLocalPlayer {
                    Capsule().fill(Theme.Palette.poseCorrect)
                }
            }
        )
    }

    @ViewBuilder
    private func rankMark(_ rank: Int) -> some View {
        switch rank {
        case 1: Image("1st").resizable().scaledToFit().frame(width: rowHeight, height: rowHeight)
        case 2: Image("2nd").resizable().scaledToFit().frame(width: rowHeight, height: rowHeight)
        case 3: Image("3rd").resizable().scaledToFit().frame(width: rowHeight, height: rowHeight)
        default:
            Text("#\(rank)")
                .font(Theme.Fonts.label(20))
                .frame(height: rowHeight)
        }
    }
}

#Preview {
    ZStack {
        PaintTexture()
        LeaderboardPopupView(
            viewModel: LeaderboardViewModel(gameCenter: PreviewLeaderboardService()),
            onClose: {}
        )
    }
    .ignoresSafeArea()
    .environment(\.strings, Localizer(language: .english))
}

/// Fake data so the popup can be designed without a signed-in device.
private final class PreviewLeaderboardService: LeaderboardProviding {
    let isAuthenticated = true

    func authenticate() async {}
    func submit(score: Int) async {}

    func loadLeaderboard(topCount: Int) async -> LeaderboardResult {
        let top = [
            LeaderboardEntry(id: "1", rank: 1, displayName: "ROO", score: 30920, isLocalPlayer: false),
            LeaderboardEntry(id: "2", rank: 2, displayName: "ZOO", score: 30000, isLocalPlayer: false),
            LeaderboardEntry(id: "3", rank: 3, displayName: "BOO", score: 29000, isLocalPlayer: false),
            LeaderboardEntry(id: "4", rank: 4, displayName: "DOO", score: 28390, isLocalPlayer: false),
            LeaderboardEntry(id: "5", rank: 5, displayName: "MOO", score: 27800, isLocalPlayer: false),
            LeaderboardEntry(id: "6", rank: 6, displayName: "NOO", score: 27800, isLocalPlayer: false),
        ]
        let localPlayer = LeaderboardEntry(id: "me", rank: 100, displayName: "You", score: 12003, isLocalPlayer: true)
        return .entries(top: top, localPlayer: localPlayer)
    }
}
