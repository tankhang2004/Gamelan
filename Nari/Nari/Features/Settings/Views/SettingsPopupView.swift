import SwiftUI

/// Music volume, sound effect volume, and language, presented over the menu.
struct SettingsPopupView: View {
    @Bindable var viewModel: SettingsViewModel
    let onClose: () -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        PopupCard(title: strings[.settingsTitle], onClose: onClose) {
            VStack(alignment: .leading, spacing: 28) {
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

                HStack {
                    Spacer()
                    Button(strings[.settingsDone], action: onClose)
                        .buttonStyle(PopupActionButtonStyle())
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    private func volumeRow(title: String, symbol: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(Theme.Fonts.label(19))
                    .foregroundStyle(Theme.Palette.ink)
                Spacer()
                Text(viewModel.percentText(for: value.wrappedValue))
                    .font(Theme.Fonts.label(17))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Palette.woodMid)
            }

            Slider(value: value, in: 0...1)
                .tint(Theme.Palette.curtainRed)
        }
    }

    private var languageRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(strings[.settingsLanguage], systemImage: "globe")
                .font(Theme.Fonts.label(19))
                .foregroundStyle(Theme.Palette.ink)

            Picker(strings[.settingsLanguage], selection: $viewModel.language) {
                ForEach(viewModel.availableLanguages) { language in
                    Text(language.nativeName).tag(language)
                        .foregroundStyle(Theme.Palette.ink)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

#Preview {
    let services = AppServices.preview()
    return ZStack {
        StageBackdropView()
        SettingsPopupView(viewModel: SettingsViewModel(settings: services.settings), onClose: {})
    }
    .environment(\.strings, services.settings.localizer)
}
