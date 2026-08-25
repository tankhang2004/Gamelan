import SwiftUI

/// The strip of floor a Leyak is about to come down, lit up before it does.
///
/// Drawn to the width that actually kills rather than to the width of the
/// artwork — the Leyak is mostly trailing hair, and flagging all of it would
/// send the player further than they need to go.
struct LeyakWarningView: View {
    /// Where it will fall, in normalized image x.
    let column: CGFloat
    /// 0 the instant the column lights up, 1 as the dive begins.
    let progress: Double
    /// Places the band the same way the Leyak itself is placed, so the two
    /// line up on the picture.
    let mapper: CameraFrameMapper

    /// Matches `RunRules.leyakColumnHalfWidth`.
    var halfWidth: CGFloat = RunRules.default.leyakColumnHalfWidth

    var body: some View {
        GeometryReader { proxy in
            let x = mapper.point(CGPoint(x: column, y: 0.5)).x
            let width = max(mapper.length(halfWidth * 2), 40)

            ZStack {
                // Brightest along the centre line and falling away to the
                // edges, so the column reads as a beam over the room rather
                // than a flat rectangle stuck to the glass.
                LinearGradient(
                    colors: [
                        Theme.Palette.poseWrong.opacity(0.05),
                        Theme.Palette.poseWrong.opacity(0.42),
                        Theme.Palette.poseWrong.opacity(0.05),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                // The edges stay hard while the fill pulses, so the exact
                // strip to be out of is never in doubt.
                HStack {
                    edge
                    Spacer(minLength: 0)
                    edge
                }
            }
            .frame(width: width, height: proxy.size.height)
            .position(x: x, y: proxy.size.height / 2)
            // Quickens as the dive approaches rather than pulsing at a
            // constant rate: the urgency is the countdown, not the colour.
            .opacity(0.55 + 0.45 * abs(sin(progress * .pi * 4)))
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var edge: some View {
        Rectangle()
            .fill(Theme.Palette.poseWrong.opacity(0.9))
            .frame(width: 4)
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
        LeyakWarningView(column: 0.5, progress: 0.3, mapper: mapper)
    }
    .frame(width: 900, height: 620)
}
