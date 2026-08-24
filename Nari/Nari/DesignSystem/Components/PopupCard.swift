import SwiftUI

/// Shared chrome for the popups: dimmed backdrop, torn paper card, painted
/// header bar, and a close button.
struct PopupCard<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content

    /// Fixed so the tear in the paper does not change shape between popups.
    private let paperSeed: UInt64 = 41

    @Environment(\.audio) private var audio

    var body: some View {
        ZStack {
            Theme.Palette.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .transition(.opacity.animation(.easeOut(duration: 0.22)))

            VStack(spacing: 0) {
                header
                content()
                    .padding(.horizontal, 44)
                    .padding(.top, 22)
                    .padding(.bottom, 34)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: Theme.Metrics.popupMaxWidth, maxHeight: Theme.Metrics.popupMaxHeight)
            .background(
                Image("backset")
                    .resizable()
                    .scaledToFill()
            )
            .compositingGroup()
            .shadow(color: Theme.Palette.ink.opacity(0.45), radius: 26, y: 14)
            .padding(.vertical, 40)
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
        }
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(Theme.Fonts.title(64))
                .foregroundStyle(Theme.Palette.ink)

            HStack {
                Spacer()
                Button(action: {
                    audio.play(.buttonTap)
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.Palette.ink)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Theme.Palette.ink.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
            }
        }
        .frame(height: 78)
        .padding(.top, 54)
    }
}

/// A smaller painted pill for popup actions, so a popup does not have to reach
/// for the full-size menu button.
struct PopupActionButtonStyle: ButtonStyle {
    @Environment(\.audio) private var audio

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.label(32))
            .foregroundStyle(Theme.Palette.cream)
            .padding(.horizontal, 34)
            .padding(.vertical, 13)
            .background(Capsule().fill(Theme.Palette.indigo.opacity(configuration.isPressed ? 0.8 : 1)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { audio.play(.buttonTap) }
            }
    }
}

#Preview {
    ZStack {
        Image("bg-yellow")
            .resizable()
            .scaledToFill()

        PopupCard(title: "Settings", onClose: {}) {
            VStack(spacing: 20) {
                Text("Sample popup content")
                    .font(Theme.Fonts.body(18))
            }
        }
    }
    .ignoresSafeArea()
}
