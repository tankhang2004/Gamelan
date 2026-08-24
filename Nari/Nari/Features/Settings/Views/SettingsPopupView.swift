import SwiftUI

/// Music volume, sound effect volume, and language, presented over the menu.
struct SettingsPopupView: View {
    @Bindable var viewModel: SettingsViewModel
    let onClose: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        PopupCard(title: strings[.settingsTitle], onClose: onClose) {
            VStack(alignment: .leading, spacing: 64) {
                volumeRow(
                    title: strings[.settingsMusicVolume],
                    symbol: "music.note",
                    value: $viewModel.musicVolume
                )

                volumeRow(
                    title: strings[.settingsSFXVolume],
                    symbol: "speaker.wave.2.fill",
                    value: $viewModel.sfxVolume
                )

                languageRow
            }
        }
    }

    private func volumeRow(title: String, symbol: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(Theme.Fonts.label(28))
                    .foregroundStyle(Theme.Palette.ink)
                Spacer()
                Text(viewModel.percentText(for: value.wrappedValue))
                    .font(Theme.Fonts.label(24))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Palette.ink.opacity(0.6))
            }

            PaintedSlider(value: value)
        }
    }

    private var languageRow: some View {
        VStack(alignment: .leading, spacing: 36) {
            Label(strings[.settingsLanguage], systemImage: "globe")
                .font(Theme.Fonts.label(28))
                .foregroundStyle(Theme.Palette.ink)

            Picker(strings[.settingsLanguage], selection: $viewModel.language) {
                ForEach(viewModel.availableLanguages) { language in
                    Text(language.nativeName).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)
            .onAppear {
                UISegmentedControl.appearance().setTitleTextAttributes(
                    [.font: UIFont.systemFont(ofSize: 24, weight: .regular), .foregroundColor: UIColor.black],
                    for: .normal
                )
                UISegmentedControl.appearance().setTitleTextAttributes(
                    [.font: UIFont.systemFont(ofSize: 24, weight: .semibold), .foregroundColor: UIColor.black],
                    for: .selected
                )
            }
        }
    }
}

#Preview {
    let services = AppServices.preview()
    return ZStack {
        Image("bg-yellow")
            .resizable()
            .scaledToFill()
                SettingsPopupView(viewModel: SettingsViewModel(settings: services.settings), onClose: {})
    }
    .environment(\.strings, services.settings.localizer)
}
