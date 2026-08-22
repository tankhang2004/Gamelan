import SwiftUI

/// Shared chrome for the popups: dimmed backdrop, torn paper card, painted
/// header bar, and a close button.
struct PopupCard<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content

    /// Fixed so the tear in the paper does not change shape between popups.
    private let paperSeed: UInt64 = 41

    var body: some View {
        ZStack {
            Theme.Palette.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                header
                content()
                    .padding(.horizontal, 36)
                    .padding(.top, 22)
                    .padding(.bottom, 34)
            }
            .frame(maxWidth: Theme.Metrics.popupMaxWidth)
            .background(
                Image("backset")
                    .resizable()
                    .scaledToFill()
            )
            .overlay(
                TornEdgeShape(seed: paperSeed, roughness: 0.018)
                    .stroke(Theme.Palette.ink, lineWidth: 6)
            )
            .shadow(color: Theme.Palette.ink.opacity(0.45), radius: 26, y: 14)
            .padding(.vertical, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    private var header: some View {
        ZStack {
            Theme.Palette.indigo

            Text(title)
                .font(Theme.Fonts.title(30))
                .foregroundStyle(Theme.Palette.cream)

            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Palette.cream)
                        .padding(12)
                        .background(Circle().fill(Theme.Palette.ink.opacity(0.3)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
            }
        }
        .frame(height: 78)
    }
}

/// A smaller painted pill for popup actions, so a popup does not have to reach
/// for the full-size menu button.
struct PopupActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.label(20))
            .foregroundStyle(Theme.Palette.cream)
            .padding(.horizontal, 34)
            .padding(.vertical, 13)
            .background(Capsule().fill(Theme.Palette.indigo.opacity(configuration.isPressed ? 0.8 : 1)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

#Preview {
    ZStack {
        Image("bg-yellow")
            .resizable()
            .scaledToFill()

        PopupCard(title: "", onClose: {}) {
            VStack(spacing: 20) {
                Text("Sample popup content")
                    .font(Theme.Fonts.body(18))
            }
        }
    }
    .ignoresSafeArea()
}
