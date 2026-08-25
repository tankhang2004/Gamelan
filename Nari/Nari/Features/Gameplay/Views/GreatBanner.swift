import SwiftUI

/// The painted "GREAT SQUAT" / "GREAT AGEM" stamp.
///
/// Unlike the small text flash at the bottom of the stage, this covers half
/// the screen — so it has to take itself away again rather than sitting there
/// until the next event lands, which is what `lastEvent` alone would do.
struct GreatBanner: View {
    let artworkName: String
    /// When the event that triggered this landed. Changing it re-runs the
    /// show-and-hide, so two holds in a row each get their own stamp.
    let stamp: Date

    /// How long the stamp stays up before it clears itself off the camera.
    private static let holdSeconds: Double = 1.3

    @State private var isShowing = false

    var body: some View {
        GeometryReader { proxy in
            Image(artworkName)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width * 0.5)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .opacity(isShowing ? 1 : 0)
                .scaleEffect(isShowing ? 1 : 0.72)
                .rotationEffect(.degrees(isShowing ? -2 : -8))
        }
        .allowsHitTesting(false)
        .task(id: stamp) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { isShowing = true }
            try? await Task.sleep(for: .seconds(Self.holdSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { isShowing = false }
        }
    }
}

#Preview {
    ZStack {
        Theme.Palette.indigoDeep
        GreatBanner(artworkName: "great-agem", stamp: .now)
    }
    .ignoresSafeArea()
}
