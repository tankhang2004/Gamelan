import SwiftUI

/// Wherever each tracked hand currently sits on screen, already run through
/// the camera-to-preview mapping so it lines up with SwiftUI's own layout.
/// Set once at the top of the gameplay stage and read by every
/// `HandHoverButton` beneath it; empty off the gameplay stage.
private struct HandScreenPositionsKey: EnvironmentKey {
    static let defaultValue: [CGPoint] = []
}

extension EnvironmentValues {
    var handScreenPositions: [CGPoint] {
        get { self[HandScreenPositionsKey.self] }
        set { self[HandScreenPositionsKey.self] = newValue }
    }
}

/// A button that fires either from a tap or from holding a tracked hand over
/// it for a moment. The player is usually a few metres from the iPad
/// mid-dance, so reaching over to tap Pause or Retry breaks the session —
/// this lets the same tracking the game already reads for scoring double as
/// a remote control. Hovering grows the button and closes a glowing border
/// around it, the same visual language `StageProgressBorder` uses for the
/// calibration hold; stepping away before it closes cancels.
struct HandHoverButton<Label: View>: View {
    var action: () -> Void
    var glowColor: Color = Theme.Palette.poseCorrect
    var holdSeconds: Double = 1.5
    /// How far past the button's own bounds a hand still counts as "over"
    /// it — a wrist is a small, imprecise target next to a real button.
    var touchMargin: CGFloat = 32
    @ViewBuilder var label: () -> Label

    @Environment(\.handScreenPositions) private var handScreenPositions
    @Environment(\.audio) private var audio
    @State private var hoverProgress: Double = 0
    @State private var hasFired = false
    @State private var lastTick: Date?

    var body: some View {
        Button(action: fire, label: label)
            .scaleEffect(1 + 0.16 * hoverProgress)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: handScreenPositions) { _, points in
                            advance(hovering: isHovered(points, in: proxy))
                        }
                }
            )
            .overlay(
                // No rotation here: `RoundedRectangle`'s trace already starts
                // along the top edge and runs clockwise, same as
                // `StageProgressBorder`. A `Circle`-style `-90°` correction
                // (for a path that starts at 3 o'clock instead) looked right
                // on the round pause button only because a circle can't show
                // where its own start point is — on a wide pill it rotated
                // the fill onto a side, so it visibly grew up an end cap
                // instead of sweeping across the length of the button.
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .trim(from: 0, to: hoverProgress)
                    .stroke(glowColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .shadow(color: glowColor.opacity(0.8), radius: 10)
                    .padding(-9)
                    .opacity(hoverProgress > 0.02 ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: hoverProgress)
    }

    private func fire() {
        hoverProgress = 0
        hasFired = false
        audio.play(.buttonTap)
        action()
    }

    private func isHovered(_ points: [CGPoint], in proxy: GeometryProxy) -> Bool {
        guard !points.isEmpty else { return false }
        let frame = proxy.frame(in: .global).insetBy(dx: -touchMargin, dy: -touchMargin)
        return points.contains { frame.contains($0) }
    }

    private func advance(hovering: Bool) {
        let now = Date.now
        let delta = min(max(lastTick.map { now.timeIntervalSince($0) } ?? 0, 0), 0.2)
        lastTick = now

        if hovering {
            hoverProgress = min(1, hoverProgress + delta / holdSeconds)
            if hoverProgress >= 1, !hasFired {
                hasFired = true
                audio.play(.buttonTap)
                action()
            }
        } else {
            // Drains a little faster than it fills, so stepping away reads
            // as a clear cancel rather than lingering half full.
            hoverProgress = max(0, hoverProgress - delta / holdSeconds * 1.6)
            hasFired = false
        }
    }
}
