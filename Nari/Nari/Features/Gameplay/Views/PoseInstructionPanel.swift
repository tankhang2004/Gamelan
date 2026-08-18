import SwiftUI
import UIKit

/// The column beside the camera: which pose to hold, how it looks, how many
/// have been completed, and the pause button.
struct PoseInstructionPanel: View {
    let pose: PoseDefinition
    let language: AppLanguage
    let completedReps: Int
    let holdProgress: Double
    let onPause: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(spacing: 16) {
            Text(pose.name(for: language))
                .font(Theme.Fonts.title(30))
                .foregroundStyle(Theme.Palette.ink)

            poseArtwork
                .frame(maxHeight: .infinity)

            Text(pose.instruction(for: language))
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Palette.ink.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            holdMeter

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.Palette.poseCorrect)
                Text("\(strings[.playReps]): \(completedReps)")
                    .font(Theme.Fonts.label(16))
                    .foregroundStyle(Theme.Palette.ink)
            }

            Button(strings[.playPause], action: onPause)
                .buttonStyle(PopupActionButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.parchment)
    }

    private var poseArtwork: some View {
        Group {
            if let name = pose.artworkName, let image = UIImage(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // Stand-in until the pose illustration is drawn.
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            Theme.Palette.ink.opacity(0.35),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                        )
                    Image(systemName: "figure.dance")
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .foregroundStyle(Theme.Palette.ink.opacity(0.75))
                }
            }
        }
    }

    /// Mirrors the border progress so the player can also read the hold from
    /// the panel without looking away from their own body.
    private var holdMeter: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Theme.Palette.ink.opacity(0.12))
            GeometryReader { proxy in
                Capsule()
                    .fill(Theme.Palette.poseCorrect)
                    .frame(width: proxy.size.width * max(0, min(1, holdProgress)))
            }
        }
        .frame(height: 10)
        .animation(.linear(duration: 0.1), value: holdProgress)
    }
}

#Preview {
    PoseInstructionPanel(
        pose: .fallbackAgem,
        language: .indonesian,
        completedReps: 2,
        holdProgress: 0.45,
        onPause: {}
    )
    .frame(width: 260, height: 700)
    .environment(\.strings, Localizer(language: .indonesian))
}
