import SwiftUI

/// The end of a run: the camera dimmed behind a slab of pink paint, the final
/// score, and the two ways out.
struct GameOverView: View {
    let score: Int
    let survived: String
    let isBest: Bool
    let onRetry: () -> Void
    let onMenu: () -> Void

    @Environment(\.strings) private var strings
    @State private var landed = false

    var body: some View {
        ZStack {
            Theme.Palette.ink.opacity(0.68)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                mark

                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(Theme.Fonts.readout(72))
                        .foregroundStyle(Theme.Palette.cream)
                    Text("\(strings[.gameOverSurvived]) \(survived)")
                        .font(Theme.Fonts.body(20))
                        .foregroundStyle(Theme.Palette.cream.opacity(0.75))

                    if isBest {
                        Label(strings[.gameOverBest], systemImage: "crown.fill")
                            .font(Theme.Fonts.label(21))
                            .foregroundStyle(Theme.Palette.ochre)
                            .padding(.top, 6)
                    }
                }

                HStack(spacing: 20) {
                    Button(strings[.gameOverRetry], action: onRetry)
                        .buttonStyle(PaintedButtonStyle(height: 76, fontSize: 32))

                    Button(strings[.gameplayBack], action: onMenu)
                        .buttonStyle(.plain)
                        .font(Theme.Fonts.label(21))
                        .foregroundStyle(Theme.Palette.cream.opacity(0.85))
                }
            }
            .opacity(landed ? 1 : 0)
            .scaleEffect(landed ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(Theme.Motion.cueDrop) { landed = true }
        }
    }

    private var mark: some View {
        Text(strings[.gameOverTitle])
            .font(Theme.Fonts.title(96))
            .foregroundStyle(Theme.Palette.ink)
            .padding(.horizontal, 90)
            .padding(.vertical, 40)
            .background(
                BrushSwatchShape(seed: 27, roughness: 0.11)
                    .fill(Theme.Palette.gameOverPink)
            )
            .rotationEffect(.degrees(-2))
    }
}

#Preview {
    ZStack {
        PaintTexture()
        GameOverView(score: 1342, survived: "01:45", isBest: true, onRetry: {}, onMenu: {})
    }
    .ignoresSafeArea()
    .environment(\.strings, Localizer(language: .english))
}
