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
                lineView(line)
            }

            Rectangle()
                .fill(Theme.Palette.ink.opacity(0.22))
                .frame(height: 1)
                .padding(.top, 6)
        }
    }

    /// Lines starting with a "1. " style numeral get a hanging indent so a
    /// wrapped second line lines up under the text, not under the number.
    @ViewBuilder
    private func lineView(_ line: String) -> some View {
        if let (number, rest) = numberedListPrefix(of: line) {
            HStack(alignment: .top, spacing: 10) {
                Text(number)
                    .font(Theme.Fonts.body(24))
                    .foregroundStyle(Theme.Palette.ink.opacity(0.9))
                    .frame(width: 28, alignment: .trailing)

                Text(.init(rest))
                    .font(Theme.Fonts.body(24))
                    .foregroundStyle(Theme.Palette.ink.opacity(0.9))
                    .tint(Theme.Palette.indigo)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(.init(line))
                .font(Theme.Fonts.body(24))
                .foregroundStyle(Theme.Palette.ink.opacity(0.9))
                .tint(Theme.Palette.indigo)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func numberedListPrefix(of line: String) -> (number: String, rest: String)? {
        guard let range = line.range(of: #"^\d+\."#, options: .regularExpression) else { return nil }
        let rest = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
        return (String(line[..<range.upperBound]), rest)
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
