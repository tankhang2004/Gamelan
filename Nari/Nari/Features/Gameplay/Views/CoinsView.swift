import SwiftUI

/// The coins scattered around the player during the walk.
///
/// One style of coin at ten sizes: the small ones sit in close and are worth
/// little, the big ones sit out at arm's length and are worth the most, so the
/// size on screen reads as the reward before the number does.
struct CoinsView: View {
    let placements: [CoinPlacement]
    let mapper: CameraFrameMapper

    var body: some View {
        ZStack {
            ForEach(placements) { placement in
                let radius = mapper.length(placement.radius)
                CoinView(value: placement.value, radius: radius)
                    // The last second drains the ring around the coin, so a
                    // player can see which coin is about to go without having
                    // to have watched it arrive.
                    .overlay { timeRing(placement: placement, radius: radius) }
                    .position(mapper.point(placement.center))
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: placements.map(\.id))
    }

    private func timeRing(placement: CoinPlacement, radius: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: placement.remainingFraction)
            .stroke(
                Theme.Palette.cream.opacity(0.9),
                style: StrokeStyle(lineWidth: max(3, radius * 0.12), lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: radius * 2.3, height: radius * 2.3)
    }
}

/// A single painted coin with its value stamped across it.
private struct CoinView: View {
    let value: Int
    let radius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.Palette.ochreLight, Theme.Palette.ochre, Theme.Palette.ochreDeep],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: radius * 1.2
                    )
                )
            Circle()
                .strokeBorder(Theme.Palette.ochreDeep, lineWidth: max(2, radius * 0.1))
                .padding(radius * 0.18)
            Circle()
                .strokeBorder(Theme.Palette.ink, lineWidth: max(2.5, radius * 0.11))

            Text("\(value)")
                .font(Theme.Fonts.readout(max(11, radius * 0.72)))
                .foregroundStyle(Theme.Palette.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, radius * 0.3)
        }
        .frame(width: radius * 2, height: radius * 2)
        .shadow(color: Theme.Palette.ink.opacity(0.35), radius: radius * 0.2, y: radius * 0.12)
    }
}

#Preview {
    let mapper = CameraFrameMapper(
        imageSize: CGSize(width: 1280, height: 720),
        viewSize: CGSize(width: 900, height: 506),
        isMirrored: false
    )
    return CoinsView(
        placements: (1...4).map { tier in
            CoinPlacement(
                id: UUID(),
                value: tier * 25,
                center: CGPoint(x: 0.18 * Double(tier) + 0.1, y: 0.5),
                radius: 0.03 + 0.022 * Double(tier),
                remainingFraction: Double(tier) / 4
            )
        },
        mapper: mapper
    )
    .frame(width: 900, height: 506)
    .background(Theme.Palette.indigoDeep)
}
