import SwiftUI

/// Shared chrome for the settings and credits popups: dimmed backdrop, parchment
/// card with a gold frame, title bar, and a close button.
struct PopupCard<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Theme.Palette.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                header
                content()
                    .padding(.horizontal, 32)
                    .padding(.vertical, 26)
            }
            .frame(maxWidth: Theme.Metrics.popupMaxWidth)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.popupCornerRadius, style: .continuous)
                    .fill(Theme.Palette.parchment)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.popupCornerRadius, style: .continuous)
                    .strokeBorder(Theme.Palette.goldTrim, lineWidth: 4)
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 14)
            .padding(.vertical, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    private var header: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Palette.curtainRed, Theme.Palette.curtainRedDeep],
                startPoint: .top,
                endPoint: .bottom
            )

            Text(title)
                .font(Theme.Fonts.title(28))
                .foregroundStyle(Theme.Palette.parchment)

            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Palette.parchment)
                        .padding(12)
                        .background(Circle().fill(Color.black.opacity(0.22)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
        }
        .frame(height: 72)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: Theme.Metrics.popupCornerRadius - 4,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Theme.Metrics.popupCornerRadius - 4,
                style: .continuous
            )
        )
    }
}
