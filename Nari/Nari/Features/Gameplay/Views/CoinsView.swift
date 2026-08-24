import SwiftUI

/// The frangipanis scattered around the player during the march.
///
/// A flower is drawn at whatever size it has wilted to, so the size on screen
/// is the reward readout: the big fresh one across the room pays most, and
/// every one of them is quietly shrinking towards nothing. No countdown ring
/// any more — the flower closing in on itself *is* the timer.
struct CoinsView: View {
    let placements: [CoinPlacement]
    let mapper: CameraFrameMapper

    var body: some View {
        ZStack {
            ForEach(placements) { placement in
                FrangipaniView(value: placement.value, radius: mapper.length(placement.radius))
                    .position(mapper.point(placement.center))
                    // Bloom open on arrival, fold away when picked or spent.
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.1).combined(with: .opacity),
                        removal: .scale(scale: 1.5).combined(with: .opacity)
                    ))
            }
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: placements.map(\.id))
    }
}

/// One frangipani with what it is currently worth printed under it.
private struct FrangipaniView: View {
    let value: Int
    let radius: CGFloat

    /// A slow idle turn, seeded per flower so no two spin in step.
    @State private var sway = false

    var body: some View {
        VStack(spacing: radius * 0.08) {
            Image("Frangipani")
                .resizable()
                .scaledToFit()
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(sway ? 6 : -6))
                .shadow(color: Theme.Palette.ink.opacity(0.45), radius: radius * 0.18, y: radius * 0.12)

            Text("\(value)")
                .font(Theme.Fonts.readout(max(11, radius * 0.5)))
                .foregroundStyle(.white)
                .outlined(color: Theme.Palette.ink, width: 1.5)
                .lineLimit(1)
        }
        .onAppear { sway = true }
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: sway)
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
