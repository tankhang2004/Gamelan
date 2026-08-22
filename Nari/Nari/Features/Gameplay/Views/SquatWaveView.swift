import SwiftUI

/// The wave that rolls over the player while they hold a nge'ed.
///
/// The squat hold needs a reason to exist beyond a number counting down, so
/// there is something overhead to stay under. The swell reaches deepest halfway
/// through the hold and lifts again at the end, which puts the hardest moment
/// in the middle instead of at the finish line.
struct SquatWaveView: View {
    /// 0 to 1 across the hold.
    let progress: Double

    var body: some View {
        // Deepest in the middle of the hold, shallow at both ends.
        let swell = sin(min(max(progress, 0), 1) * .pi)
        let depth = 0.16 + 0.30 * swell
        let phase = progress * 4 * .pi

        ZStack(alignment: .top) {
            WaveShape(phase: phase, depth: depth, amplitude: 0.035)
                .fill(
                    LinearGradient(
                        // Translucent on purpose: a player who stands into the
                        // wave still has to be able to see themselves do it.
                        colors: [Theme.Palette.indigoDeep.opacity(0.62), Theme.Palette.indigo.opacity(0.42)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // The foam line reads as the edge to stay under even for a player
            // who cannot pick the blue out from the camera picture behind it.
            WaveShape(phase: phase, depth: depth, amplitude: 0.035)
                .stroke(Theme.Palette.cream, lineWidth: 7)

            WaveShape(phase: phase + 0.6, depth: depth - 0.035, amplitude: 0.03)
                .stroke(Theme.Palette.indigoLight.opacity(0.7), lineWidth: 4)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// Everything above a rolling sine line.
private struct WaveShape: Shape {
    /// Scrolls the crests sideways.
    var phase: Double
    /// How far down the screen the water reaches, as a fraction of the height.
    var depth: Double
    /// Crest height, also as a fraction of the height.
    var amplitude: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(phase, depth) }
        set {
            phase = newValue.first
            depth = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseline = rect.height * depth
        let height = rect.height * amplitude
        // Two and a bit crests across the screen, so the shape reads as a wave
        // rather than as a ripple or a single hump.
        let wavelength = rect.width / 2.3

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // Right to left, so the line joins the top edge cleanly at both ends.
        let steps = 48
        for step in stride(from: steps, through: 0, by: -1) {
            let x = rect.width * Double(step) / Double(steps)
            let y = baseline + sin(x / wavelength * 2 * .pi + phase) * height
            path.addLine(to: CGPoint(x: rect.minX + x, y: rect.minY + y))
        }

        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach([0.15, 0.5, 0.85], id: \.self) { progress in
            ZStack {
                Theme.Palette.paperShade
                SquatWaveView(progress: progress)
            }
            .frame(height: 200)
        }
    }
}
