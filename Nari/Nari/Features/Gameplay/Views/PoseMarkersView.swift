import SwiftUI

/// The dots drawn over the player: green once that body point is in the right
/// place, red while it is not, with a ring that fills as the point is held.
///
/// A faint dashed circle shows where the point is supposed to be, so a player
/// who is wrong can see which way to move.
struct PoseMarkersView: View {
    let markers: [PoseEvaluation.Marker]
    let progress: [TrackedBodyPoint: Double]
    let mapper: CameraFrameMapper
    let showsTargets: Bool

    private let radius: CGFloat = 34

    var body: some View {
        ZStack {
            if showsTargets {
                ForEach(markers) { marker in
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(0.55),
                            style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                        )
                        .frame(width: radius * 2, height: radius * 2)
                        .position(mapper.point(marker.target))
                }
            }

            ForEach(markers) { marker in
                markerView(marker)
                    .position(mapper.point(marker.detected))
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.12), value: markers.map(\.isCorrect))
    }

    private func markerView(_ marker: PoseEvaluation.Marker) -> some View {
        let color = marker.isCorrect ? Theme.Palette.poseCorrect : Theme.Palette.poseWrong
        let filled = progress[marker.point] ?? 0

        return ZStack {
            Circle()
                .fill(color.opacity(0.55))
                .frame(width: radius * 1.7, height: radius * 1.7)

            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 3)
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .trim(from: 0, to: filled)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: radius * 2, height: radius * 2)
        }
        .shadow(color: .black.opacity(0.3), radius: 6)
    }
}
