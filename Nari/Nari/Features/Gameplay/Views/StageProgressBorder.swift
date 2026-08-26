import SwiftUI

/// A bar that runs around the edge of the screen and fills up as an action is
/// completed. Used for the calibration countdown and for the pose hold.
struct StageProgressBorder: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 18
    var cornerRadius: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(color.opacity(0.18), lineWidth: lineWidth)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .shadow(color: color.opacity(0.6), radius: 12)
        }
        .animation(.linear(duration: 0.1), value: progress)
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.black
        StageProgressBorder(progress: 0.4, color: Theme.Palette.poseCorrect)
            .padding(8)
    }
    .ignoresSafeArea()
}
