import SwiftUI

/// Hand-painted volume slider built from three assets: `SLIDER-bg` is the
/// empty track, `SLIDER-bar` is the fill clipped to the current value, and
/// `SLIDER-ball` is the thumb riding at the end of the fill.
struct PaintedSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1

    /// Matches the 792×100 art so the track never looks squashed or stretched.
    private let trackAspectRatio: CGFloat = 792 / 100
    private let ballDiameter: CGFloat = 44
    /// Fill sits a touch smaller than the track outline so the bg's edge shows through.
    private let barScale: CGFloat = 0.8
    /// Nudges the thumb left so it doesn't overshoot the painted fill's tip.
    private let ballOffsetX: CGFloat = 0

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return ((value - range.lowerBound) / span).clamped(to: 0...1)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let trackHeight = width / trackAspectRatio
            let edgeInset: CGFloat = 14
            let usable = max(width - ballDiameter - edgeInset * 2, 0)
            let fillWidth = ballDiameter / 2 + edgeInset + usable * fraction

            ZStack(alignment: .leading) {
                Image("SLIDER-bg")
                    .resizable()
                    .frame(width: width, height: trackHeight)

                Image("SLIDER-bar")
                    .resizable()
                    .frame(width: width, height: trackHeight * barScale)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: fillWidth, height: trackHeight)
                    }

                Image("SLIDER-ball")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: ballDiameter, height: ballDiameter)
                    .position(x: fillWidth + ballOffsetX, y: trackHeight / 2)
            }
            .frame(width: width, height: trackHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let x = (drag.location.x - ballDiameter / 2 - edgeInset).clamped(to: 0...usable)
                        let newFraction = usable > 0 ? x / usable : 0
                        value = range.lowerBound + newFraction * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: ballDiameter)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    @Previewable @State var value = 0.8
    return PaintedSlider(value: $value)
        .padding(40)
        .background(Theme.Palette.paper)
}
