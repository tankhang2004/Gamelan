import SwiftUI

/// The end of a run: score on the left, a playback of the run on the right,
/// and the ways to replay, share, or save it. Kept neutral on purpose — this
/// is a session summary, not a win or lose screen.
struct GameOverView: View {
    let score: Int
    let survived: String
    let isBest: Bool
    let bestScore: Int
    let onRetry: () -> Void
    let onShare: () -> Void
    let onDownload: () -> Void
    let onMenu: () -> Void

    @Environment(\.strings) private var strings
    @State private var landed = false

    var body: some View {
        ZStack {
            Theme.Palette.ink.opacity(0.55)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    PaintedIconButton(symbol: "xmark", diameter: 64, action: onMenu)
                }

                Spacer()

                HStack(alignment: .center, spacing: 48) {
                    scoreSection
                    videoPlaybackPlaceholder
                }

                Spacer()

                actionRow
            }
            .padding(32)
            .opacity(landed ? 1 : 0)
            .scaleEffect(landed ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(Theme.Motion.cueDrop) { landed = true }
        }
    }

    // MARK: - Score

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings[.gameOverYourScore])
                .font(Theme.Fonts.title(44))
                .foregroundStyle(Theme.Palette.indigo)

            Text("\(score)")
                .font(Theme.Fonts.readout(56))
                .foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Image("bg-yellow-2")
                        .resizable()
                        .frame(width: 300, height: 120)
//                    BrushSwatchShape(seed: 27, roughness: 0.08)
//                        .fill(Theme.Palette.ochre)
                )

            Text(isBest
                 ? strings[.gameOverNewHighScore]
                 : "\(strings[.gameOverBestScoreLabel]) = \(bestScore)")
                .font(Theme.Fonts.body(18))
                .foregroundStyle(.white)
                .padding(.top, 4)
        }
    }

    // MARK: - Playback

    /// Stands in for the recorded run until the recording pipeline lands.
    private var videoPlaybackPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.Palette.ink.opacity(0.3))
            .frame(width: 320, height: 240)
            .overlay(
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 2)
            )
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 20) {
            Button(strings[.gameOverRetry], action: onRetry)
                .buttonStyle(PaintedButtonStyle(height: 76, fontSize: 30))

            PaintedIconButton(symbol: "square.and.arrow.up", diameter: 64, action: onShare)

            PaintedIconButton(symbol: "arrow.down.circle", diameter: 64, action: onDownload)
        }
    }
}

#Preview {
    ZStack {
        Image("bg-yellow")
                    .resizable()
                    .scaledToFill()
        GameOverView(
            score: 21983,
            survived: "01:45",
            isBest: true,
            bestScore: 18420,
            onRetry: {},
            onShare: {},
            onDownload: {},
            onMenu: {}
        )
    }
    .ignoresSafeArea()
    .environment(\.strings, Localizer(language: .english))
}
