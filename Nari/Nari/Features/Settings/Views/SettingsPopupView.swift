import SwiftUI

/// Music volume, sound effect volume, and language, presented over the menu.
struct SettingsPopupView: View {
    @Bindable var viewModel: SettingsViewModel
    let onClose: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        PopupCard(title: strings[.settingsTitle], onClose: onClose) {
            VStack(alignment: .leading, spacing: 44) {
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
        VStack(alignment: .leading, spacing: 16) {
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

            Slider(value: value, in: 0...1)
                .tint(Theme.Palette.indigo)
                .scaleEffect(x: 1, y: 2)
                .padding(.vertical, 12)
                .onAppear {
                    UISlider.appearance().maximumTrackTintColor = UIColor.systemGray3
                }
        }
    }

    private var languageRow: some View {
        VStack(alignment: .leading, spacing: 26) {
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
                    [.font: UIFont.systemFont(ofSize: 24, weight: .semibold), .foregroundColor: UIColor.black],
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
