import SwiftUI

/// Carved-wood plaque with a gold border, in two sizes: `primary` for PLAY and
/// `secondary` for the other three entries.
struct PlaqueButtonStyle: ButtonStyle {
    let emphasis: MainMenuItem.Emphasis
    /// Supplied by `MenuLayout` so the plaques track the stage size.
    let height: CGFloat

    private var cornerRadius: CGFloat { emphasis == .primary ? 24 : 18 }

    private var fill: LinearGradient {
        switch emphasis {
        case .primary:
            LinearGradient(
                colors: [Theme.Palette.curtainGold, Theme.Palette.curtainGoldDeep],
                startPoint: .top,
                endPoint: .bottom
            )
        case .secondary:
            LinearGradient(
                colors: [Theme.Palette.woodMid, Theme.Palette.woodDark],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.Palette.goldTrimBright, Theme.Palette.goldTrim],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: emphasis == .primary ? 5 : 3
                    )
            )
            .overlay(alignment: .top) {
                // Thin highlight along the top edge so the plaque reads as carved.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .frame(height: height * 0.36)
                    .blur(radius: 8)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Compact gold button used inside popups.
struct PopupActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.label(20))
            .foregroundStyle(Theme.Palette.ink)
            .padding(.horizontal, 34)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Theme.Palette.curtainGold, Theme.Palette.curtainGoldDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(Capsule().strokeBorder(Theme.Palette.goldTrimBright, lineWidth: 2))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
