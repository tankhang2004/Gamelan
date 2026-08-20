import SwiftUI

/// A number printed on a stroke of paint — the score in the top left, the run
/// clock in the top right.
struct PaintSwatchReadout: View {
    let text: String
    var fill: Color = Theme.Palette.indigo
    var textColor: Color = Theme.Palette.cream
    var fontSize: CGFloat = 34
    var seed: UInt64 = 3

    var body: some View {
        Text(text)
            .font(Theme.Fonts.readout(fontSize))
            .foregroundStyle(textColor)
            .padding(.horizontal, fontSize * 0.9)
            .padding(.vertical, fontSize * 0.28)
            .background(BrushSwatchShape(seed: seed).fill(fill))
            .shadow(color: Theme.Palette.ink.opacity(0.28), radius: 0, x: 2, y: 4)
    }
}

/// The card on the right showing which move is being asked for, with the pose
/// silhouette above its name. Printed on torn paper like the Taksu meter.
struct PoseCueCard: View {
    let title: String
    let artworkName: String?
    let symbolName: String

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
        .padding(.horizontal, 18)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TornEdgeShape(seed: 63, roughness: 0.02).fill(Theme.Palette.paper.opacity(0.92)))
        .overlay(TornEdgeShape(seed: 63, roughness: 0.02).stroke(Theme.Palette.ink.opacity(0.5), lineWidth: 4))
        .shadow(color: Theme.Palette.ink.opacity(0.3), radius: 12, x: -3, y: 6)
    }
}

/// The banner across the top telling the player what to do right now, with the
/// cue window draining underneath it.
struct CuePromptView: View {
    let text: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(text)
                .font(Theme.Fonts.title(46))
                .foregroundStyle(Theme.Palette.cream)
                .tracking(3)
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
                    .frame(width: 320)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .background(BrushSwatchShape(seed: 11, roughness: 0.09).fill(tint.opacity(0.92)))
    }
}

#Preview {
    VStack(spacing: 30) {
        PaintSwatchReadout(text: "1342")
        PaintSwatchReadout(text: "01:45", fill: Theme.Palette.ochre, textColor: Theme.Palette.ink, seed: 8)
        CuePromptView(text: "SQUAT!", progress: 0.4, tint: Theme.Palette.cueOrange)
        PoseCueCard(title: "Agem Kanan", artworkName: nil, symbolName: "figure.stand")
            .frame(width: 220, height: 320)
    }
    .padding(40)
    .background(PaintTexture().ignoresSafeArea())
}
