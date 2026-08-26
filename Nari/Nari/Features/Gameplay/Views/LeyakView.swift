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
            // Starts exactly where the old face-anchored placement put it —
            // the face already in frame, hair trailing off the top — but
            // travels all the way until the whole image, hair included, has
            // cleared the bottom edge, rather than stopping the moment the
            // face alone gets there and cutting to the next phase with the
            // Leyak still hanging half on screen.
            let startCenterY = -height * (Self.faceAnchor - 0.5)
            let endCenterY = proxy.size.height + height / 2
            let centerY = startCenterY + (endCenterY - startCenterY) * progress
            let x = mapper.point(CGPoint(x: column, y: 0.5)).x

            Image("leak")
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .position(x: x, y: centerY)
                .drawingGroup()
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
