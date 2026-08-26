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
    let artworkName: String?
    let symbolName: String

    var body: some View {
        Group {
            if let artworkName, UIImage(named: artworkName) != nil {
                Image(artworkName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: symbolName)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .foregroundStyle(Theme.Palette.ink)
            }
        }
        // One padding for every pose, so the drawings all sit the same size
        // inside the same banner rather than each finding its own scale.
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("banner-yellow")
                .resizable()
                .scaledToFill()
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
    /// The widest the swatch may print. Left at the width it was drawn for,
    /// so anywhere with room to spare looks exactly as it always has.
    var maxWidth: CGFloat = CuePromptView.designWidth

    /// The bar plus the swatch's own margins, which is what this was drawn as.
    static let designWidth: CGFloat = 620
    private static let margin: CGFloat = 40

    /// Room left for the word and the bar under it.
    private var contentWidth: CGFloat {
        max(maxWidth - Self.margin * 2, 1)
    }

    var body: some View {
        // No draining bar under the word any more: the cue window is shown by
        // the border closing round the whole stage, the same way calibration
        // shows its hold, so there is one language for "time is running" on
        // this screen rather than two.
        Text(text)
            // A cue names its move and then says what to do with it, so it is
            // a short sentence rather than a single word — two lines at most,
            // shrinking rather than pushing the block out past its slot.
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .stageCaption(size: 38, blockOpacity: 0.6)
            .frame(maxWidth: contentWidth)
    }
}

#Preview {
    VStack(spacing: 30) {
        PaintSwatchReadout(text: "1342")
        PaintSwatchReadout(text: "01:45")
        CuePromptView(text: "SQUAT!")
        PoseCueCard(artworkName: nil, symbolName: "figure.stand")
            .frame(width: 220, height: 320)
    }
    .padding(40)
    .background(PaintTexture().ignoresSafeArea())
}
