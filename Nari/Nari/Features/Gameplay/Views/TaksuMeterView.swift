import SwiftUI

/// The Taksu meter: a painted strip down the left of the screen with the
/// energy filled into it.
///
/// It sits half faded most of the time, because the camera behind it is the
/// game — a solid bar down the edge of the picture is room the player cannot
/// dance in. It only lights up when the number actually moves, glowing green
/// on a gain and red on a loss, then settles back out of the way.
struct TaksuMeterView: View {
    let fraction: Double
    let isLow: Bool

    /// How faded the meter sits when nothing is happening to it.
    private static let restingOpacity: Double = 0.5
    /// Fraction of the bar's width the fill is shifted left by.
    private static let fillNudge: CGFloat = 0.06
    private static let flashSeconds: Double = 0.55

    @State private var pulse = false
    @State private var flashColor: Color?
    @State private var flashTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .bottom) {
                Image("energy-bg")
                    .resizable()

                // The fill artwork is drawn a touch right of centre in its own
                // canvas, so it needs nudging back to sit inside the painted
                // channel of the background rather than riding its right edge.
                Image("energy-fill")
                    .resizable()
                    .frame(height: proxy.size.height)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: proxy.size.height * clamped)
                    }
                    .offset(x: -width * Self.fillNudge)
                    .animation(Theme.Motion.meter, value: fraction)

                VStack {
                    Spacer(minLength: 0)
                    Text("\(Int(clamped * 100))%")
                        .font(Theme.Fonts.readout(width * 0.42))
                        .foregroundStyle(.white)
                        .outlined(color: Theme.Palette.ink, width: 1.5)
                        .padding(.bottom, width * 0.22)
                }
            }
            // The whole meter brightens together, so a change reads as the bar
            // reacting rather than as one layer flickering inside it.
            .opacity(flashColor == nil ? Self.restingOpacity : 1)
            .shadow(color: flashColor ?? .clear, radius: width * 0.5)
            .shadow(color: flashColor ?? .clear, radius: width * 0.18)
            .animation(.easeOut(duration: 0.18), value: flashColor)
            // Low Taksu pulses so the player notices without watching the bar.
            // Template rendering is what makes the tint take: the artwork is a
            // full-colour PNG, so a plain `foregroundStyle` would leave it
            // white and the "warning" would read as a flash of nothing.
            .overlay(
                Image("energy-bg")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(Theme.Palette.taksuLow)
                    .opacity(isLow && pulse ? 0.55 : 0)
                    .allowsHitTesting(false)
            )
        }
        .onAppear { pulse = true }
        .animation(
            isLow ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default,
            value: pulse
        )
        .onChange(of: fraction) { previous, current in
            guard abs(current - previous) > 0.0001 else { return }
            flash(current > previous ? Theme.Palette.poseCorrect : Theme.Palette.poseWrong)
        }
        .onDisappear { flashTask?.cancel() }
    }

    /// Lights the meter up in `color`, then fades it back to resting. A second
    /// change mid-flash replaces the first rather than queueing behind it, so a
    /// gain immediately after a loss shows green straight away.
    private func flash(_ color: Color) {
        flashTask?.cancel()
        flashColor = color
        flashTask = Task {
            try? await Task.sleep(for: .seconds(Self.flashSeconds))
            guard !Task.isCancelled else { return }
            flashColor = nil
        }
    }

    private var clamped: Double { max(0, min(1, fraction)) }
}

#Preview {
    struct Demo: View {
        @State private var fraction = 0.72
        var body: some View {
            HStack(spacing: 40) {
                TaksuMeterView(fraction: fraction, isLow: fraction < 0.2)
                    .frame(width: 60, height: 420)
                VStack(spacing: 12) {
                    Button("Gain") { fraction = min(1, fraction + 0.15) }
                    Button("Lose") { fraction = max(0, fraction - 0.15) }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(50)
        }
    }
    return Demo().background(Theme.Palette.indigoDeep)
}
