import SwiftUI

/// Thanks to Mekar Bhuana Centre, the inspiration behind the game.
struct CreditsPopupView: View {
    let viewModel: CreditsViewModel
    let onClose: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        PopupCard(title: strings[.creditsTitle], onClose: onClose) {
            VStack(spacing: 20) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(viewModel.sections) { section in
                            sectionView(section)
                        }
                    }
                    .padding(.trailing, 6)
                }
                .frame(maxHeight: 480)
                // Fades the last visible line so clipped text reads as "keep
                // scrolling" rather than as a rendering glitch.
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.88),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    private func sectionView(_ section: CreditSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(Theme.Fonts.label(30))
                .foregroundStyle(Theme.Palette.indigoDeep)

            ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                Text(.init(line))
                    .font(Theme.Fonts.body(24))
                    .foregroundStyle(Theme.Palette.ink.opacity(0.9))
                    .tint(Theme.Palette.indigo)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Rectangle()
                .fill(Theme.Palette.ink.opacity(0.22))
                .frame(height: 1)
                .padding(.top, 6)
        }
    }
}

#Preview {
    let services = AppServices.preview()
    return ZStack {
        CreditsPopupView(
            viewModel: CreditsViewModel(repository: services.credits, settings: services.settings),
            onClose: {}
        )
    }
    .environment(\.strings, services.settings.localizer)
}
