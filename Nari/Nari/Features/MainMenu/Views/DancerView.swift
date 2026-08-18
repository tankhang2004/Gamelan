import SwiftUI
import UIKit

/// The dancer standing centre stage.
///
/// Drops in the `Dancer` image set as soon as artwork is added to
/// `Assets.xcassets`; until then it draws a labelled silhouette placeholder so
/// the layout is already correct.
struct DancerView: View {
    var height: CGFloat = 520

    @State private var isBreathing = false

    private var artwork: UIImage? { UIImage(named: "Dancer") }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFit()
                } else {
                    placeholder
                }
            }
            .frame(height: height)
            .scaleEffect(isBreathing ? 1.012 : 0.988, anchor: .bottom)
            .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: isBreathing)

            // Contact shadow on the stage floor.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.black.opacity(0.55), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: height * 0.22
                    )
                )
                .frame(width: height * 0.46, height: height * 0.075)
                .offset(y: -height * 0.02)
        }
        .shadow(color: Theme.Palette.curtainGold.opacity(0.35), radius: 40)
        .onAppear { isBreathing = true }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Image(systemName: "figure.dance")
                .resizable()
                .scaledToFit()
                .fontWeight(.regular)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Palette.goldTrimBright, Theme.Palette.curtainGoldDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
        }
        .frame(width: height * 0.62)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    Theme.Palette.parchment.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                )
        )
        .overlay(alignment: .bottom) {
            Text("Dancer placeholder")
                .font(Theme.Fonts.body(13))
                .foregroundStyle(Theme.Palette.parchment.opacity(0.55))
                .padding(.bottom, 8)
        }
    }
}

#Preview {
    ZStack {
        StageBackdropView()
        DancerView()
    }
}
