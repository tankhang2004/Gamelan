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
                    .padding(12)
                    .foregroundStyle(Theme.Palette.ink)
            }
        }
        // One padding for every pose, so the drawings all sit the same size
        // inside the same banner rather than each finding its own scale.
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(
//            Image("banner-yellow")
//                .resizable()
//                .scaledToFill()
//        )
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
    /// Which of the five hand-painted splashes this instruction sits on —
    /// one colour per move, so the banner itself says what kind of cue this
    /// is before the player has even read the word.
    let backgroundAsset: String
    /// 0...1 fill for the hold countdown under the instruction. Nil hides the
    /// bar entirely — it only ever appears while a squat or an agem is being
    /// held, counting the same window the border round the stage is already
    /// draining, so the two never disagree about how much time is left.
    var holdProgress: Double? = nil
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
        VStack(spacing: 12) {
            // A cue names its move and then says what to do with it, so it is
            // a short sentence rather than a single word — two lines at most,
            // shrinking rather than pushing the block out past its slot. Sized
            // to be read from across the room, not off a phone held in hand.
            Text(text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .commandBannerText(size: 50)

            if let holdProgress {
                HoldCountdownBar(progress: holdProgress)
                    .frame(height: 16)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 18)
        .frame(maxWidth: contentWidth)
        .background(
            Image(backgroundAsset)
                .resizable()
                .scaledToFill()
        )
        .shadow(color: Theme.Palette.ink.opacity(0.28), radius: 0, x: 2, y: 4)
    }
}

/// The countdown for an actual hold: black creeping across a white track as
/// the pose is held, filling exactly as the ring round the stage drains —
/// two readings of the same number, one for a glance up close and one for
/// across the room.
struct HoldCountdownBar: View {
    /// 0 the instant the hold locks in, 1 once it has been held in full.
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white)
                Capsule()
                    .fill(Theme.Palette.ink)
                    .frame(width: proxy.size.width * CGFloat(progress).clamped(to: 0...1))
            }
        }
        .overlay(Capsule().strokeBorder(Theme.Palette.ink, lineWidth: 2))
    }
}

#Preview {
    VStack(spacing: 30) {
        PaintSwatchReadout(text: "1342")
        PaintSwatchReadout(text: "01:45")
        CuePromptView(text: "SQUAT!", backgroundAsset: "command-orange-squat-hold")
        CuePromptView(text: "HOLD IT!", backgroundAsset: "command-orange-squat-hold", holdProgress: 0.6)
        PoseCueCard(artworkName: nil, symbolName: "figure.stand")
            .frame(width: 220, height: 320)
    }
    .padding(40)
    .background(PaintTexture().ignoresSafeArea())
}
