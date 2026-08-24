import SwiftUI

/// The Leyak diving down the room.
///
/// It hangs into frame from the top — face first, hair trailing up off screen
/// — and falls straight down the column it was aimed at. The player has to be
/// somewhere else by the time it arrives.
struct LeyakView: View {
    /// Where it is falling, in normalized image x.
    let column: CGFloat
    /// 0 as it appears at the top, 1 as it clears the bottom.
    let progress: Double
    /// Turns the column into a screen position the same way a flower or a
    /// pose marker is placed, so the danger lines up with the picture.
    let mapper: CameraFrameMapper

    /// How tall the artwork is drawn, as a fraction of the screen height.
    private static let heightFraction: CGFloat = 1.05
    /// Where the face sits inside the artwork, top to bottom. Everything above
    /// it is hair, so this — not the image centre — is what has to travel from
    /// the top of the screen to the bottom.
    private static let faceAnchor: CGFloat = 0.78

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height * Self.heightFraction
            let faceY = proxy.size.height * progress
            let x = mapper.point(CGPoint(x: column, y: 0.5)).x

            Image("leak")
                .resizable()
                .scaledToFit()
                .frame(height: height)
                // Positioned by where the face lands rather than by the image
                // centre, so "the face is at the top edge" is true at progress
                // 0 however tall the artwork is drawn.
                .position(x: x, y: faceY - height * (Self.faceAnchor - 0.5))
                .shadow(color: Theme.Palette.ink.opacity(0.5), radius: 30)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}

#Preview {
    let mapper = CameraFrameMapper(
        imageSize: CGSize(width: 1280, height: 720),
        viewSize: CGSize(width: 900, height: 620),
        isMirrored: false
    )
    return ZStack {
        Theme.Palette.paperShade
        LeyakView(column: 0.5, progress: 0.25, mapper: mapper)
    }
    .frame(width: 900, height: 620)
}
