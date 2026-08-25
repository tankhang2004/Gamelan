import SwiftUI

/// A number printed on a stroke of paint — the score in the top left, the run
/// clock in the top right.
struct PaintSwatchReadout: View {
    let text: String
    var textColor: Color = .white
    var fontSize: CGFloat = 34

    var body: some View {
        Text(text)
            .font(Theme.Fonts.readout(fontSize))
            .foregroundStyle(textColor)
            .padding(.horizontal, fontSize * 1.1)
            .padding(.vertical, fontSize * 0.42)
            .background(
                Image("bar-purple")
                    .resizable()
                    .scaledToFill()
            )
            .shadow(color: Theme.Palette.ink.opacity(0.28), radius: 0, x: 2, y: 4)
    }
}

/// The card on the right showing which move is being asked for, with the pose
/// silhouette above its name. Printed on torn paper like the Taksu meter.
struct PoseCueCard: View {
    let title: String
    let artworkName: String?
    let symbolName: String
    /// How much of the painted backing is left. Kept low so the card reads as
    /// a reference held up over the room rather than a panel bolted across it
    /// — the player has to see themselves through the corner it occupies.
    var backingOpacity: Double = 0.22

    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)

            Group {
                if let artworkName, UIImage(named: artworkName) != nil {
                    Image(artworkName)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: symbolName)
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                }
            }
            .foregroundStyle(Theme.Palette.ink)

            Text(title)
                .font(Theme.Fonts.label(26))
                .foregroundStyle(Theme.Palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        // The dancer and her name keep their own shadow now that there is no
        // solid card behind them: ink on a bright camera frame is otherwise
        // only as readable as whatever happens to be in shot.
        .shadow(color: Theme.Palette.paper.opacity(0.9), radius: 3)
        .padding(.horizontal, 26)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("banner-yellow")
                .resizable()
                .scaledToFill()
                .opacity(backingOpacity)
        )
    }
}

/// The banner across the top telling the player what to do right now, with the
/// cue window draining underneath it.
///
/// One width for every cue, and never wider than the stage it is printed on.
/// The swatch shares a `ZStack` with the score, the meter and the pause
/// button, so it does not merely overflow when it is too wide — it makes the
/// whole stack too wide, and takes all of them off the right edge with it.
/// That is what a phone in portrait showed on every cue except the walk, the
/// one cue with no draining bar under it and so the only one narrow enough
/// to fit.
struct CuePromptView: View {
    let text: String
    let progress: Double
    let tint: Color
    /// The widest the swatch may print. Left at the width it was drawn for,
    /// so anywhere with room to spare looks exactly as it always has.
    var maxWidth: CGFloat = CuePromptView.designWidth

    /// The bar plus the swatch's own margins, which is what this was drawn as.
    static let designWidth: CGFloat = 400
    private static let margin: CGFloat = 40

    /// Room left for the word and the bar under it.
    private var contentWidth: CGFloat {
        max(maxWidth - Self.margin * 2, 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(text)
                .font(Theme.Fonts.title(46))
                .foregroundStyle(Theme.Palette.cream)
                .tracking(3)
                // A cue is one word and reads as one: a long one in a narrow
                // stage shrinks rather than wrapping, and shrinks rather than
                // pushing the swatch out past the room it was given.
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: Theme.Palette.ink, radius: 0, x: 3, y: 3)

            if progress > 0 {
                Capsule()
                    .fill(Theme.Palette.ink.opacity(0.25))
                    .frame(height: 12)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(tint)
                                .frame(width: proxy.size.width * max(0, min(1, 1 - progress)))
                        }
                    }
                    .overlay(Capsule().strokeBorder(Theme.Palette.ink, lineWidth: 3))
            }
        }
        // Written once here rather than on the bar, where it used to be a flat
        // 320 that the word above it was free to overhang.
        .frame(width: contentWidth)
        .padding(.horizontal, Self.margin)
        .padding(.vertical, 16)
        .background(BrushSwatchShape(seed: 11, roughness: 0.09).fill(tint.opacity(0.92)))
    }
}

#Preview {
    VStack(spacing: 30) {
        PaintSwatchReadout(text: "1342")
        PaintSwatchReadout(text: "01:45")
        CuePromptView(text: "SQUAT!", progress: 0.4, tint: Theme.Palette.cueOrange)
        PoseCueCard(title: "Agem Kanan", artworkName: nil, symbolName: "figure.stand")
            .frame(width: 220, height: 320)
    }
    .padding(40)
    .background(PaintTexture().ignoresSafeArea())
}
