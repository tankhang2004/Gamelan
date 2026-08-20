import SwiftUI

/// The Taksu meter: a torn strip of paper down the left of the screen with the
/// energy painted into it, and the percentage printed as a number beside it.
///
/// The number is not decoration. Judging a bar by its length alone is hard for
/// some players, and the meter is the only stat that can end a run.
struct TaksuMeterView: View {
    let fraction: Double
    let isLow: Bool

    @State private var pulse = false

    private var fill: Color {
        switch fraction {
        case ..<0.2: Theme.Palette.taksuLow
        case ..<0.5: Theme.Palette.taksuMid
        default: Theme.Palette.taksuFull
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .bottom) {
                TornEdgeShape(seed: 19, roughness: 0.012, steps: 16)
                    .fill(Theme.Palette.paper)

                Rectangle()
                    .fill(fill)
                    .frame(height: proxy.size.height * clamped)
                    .animation(Theme.Motion.meter, value: fraction)

                TornEdgeShape(seed: 19, roughness: 0.012, steps: 16)
                    .stroke(Theme.Palette.ink, lineWidth: 5)

                VStack {
                    Spacer(minLength: 0)
                    Text("\(Int(clamped * 100))%")
                        .font(Theme.Fonts.readout(width * 0.42))
                        .foregroundStyle(Theme.Palette.ink)
                        .padding(.bottom, width * 0.22)
                }
            }
            .clipShape(TornEdgeShape(seed: 19, roughness: 0.012, steps: 16))
            // Low Taksu pulses so the player notices without watching the bar.
            .overlay(
                TornEdgeShape(seed: 19, roughness: 0.012, steps: 16)
                    .stroke(Theme.Palette.taksuLow, lineWidth: 8)
                    .opacity(isLow && pulse ? 0.9 : 0)
            )
            .shadow(color: Theme.Palette.ink.opacity(0.3), radius: 10, x: 4, y: 6)
        }
        .onAppear { pulse = true }
        .animation(
            isLow ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default,
            value: pulse
        )
    }

    private var clamped: Double { max(0, min(1, fraction)) }
}

#Preview {
    HStack(spacing: 40) {
        TaksuMeterView(fraction: 0.72, isLow: false).frame(width: 60, height: 420)
        TaksuMeterView(fraction: 0.14, isLow: true).frame(width: 60, height: 420)
    }
    .padding(50)
    .background(PaintTexture().ignoresSafeArea())
}
