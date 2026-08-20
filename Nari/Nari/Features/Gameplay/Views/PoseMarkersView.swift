import SwiftUI

/// The dots drawn over the player during a Freeze: one per tracked point.
///
/// Hit and unhit differ in *shape*, not only in colour — a filled disc with a
/// tick against an open dashed ring — so a colourblind player can still read
/// which points are in place.
struct PoseMarkersView: View {
    let markers: [PoseEvaluation.Marker]
    let mapper: CameraFrameMapper

    private let radius: CGFloat = 30

    var body: some View {
        ZStack {
            ForEach(markers) { marker in
                if !marker.isCorrect {
                    // Where the point is supposed to go, so a player who is
                    // wrong can see which way to move.
                    Circle()
                        .strokeBorder(
                            Theme.Palette.ink.opacity(0.75),
                            style: StrokeStyle(lineWidth: 4, dash: [8, 7])
                        )
                        .frame(width: radius * 1.6, height: radius * 1.6)
                        .position(mapper.point(marker.target))
                }
            }

            ForEach(markers) { marker in
                markerView(marker)
                    .position(mapper.point(marker.detected))
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.14), value: markers.map(\.isCorrect))
    }

    @ViewBuilder
    private func markerView(_ marker: PoseEvaluation.Marker) -> some View {
        if marker.isCorrect {
            ZStack {
                Circle()
                    .fill(Theme.Palette.poseCorrect)
                    .frame(width: radius * 2, height: radius * 2)
                Image(systemName: "checkmark")
                    .font(.system(size: radius * 0.85, weight: .heavy))
                    .foregroundStyle(Theme.Palette.cream)
            }
            .overlay(Circle().strokeBorder(Theme.Palette.paper, lineWidth: 4))
            .shadow(color: Theme.Palette.ink.opacity(0.4), radius: 8, y: 3)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            Circle()
                .strokeBorder(Theme.Palette.poseWrong, lineWidth: 6)
                .background(Circle().fill(Theme.Palette.paper.opacity(0.28)))
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: Theme.Palette.ink.opacity(0.4), radius: 8, y: 3)
        }
    }
}
