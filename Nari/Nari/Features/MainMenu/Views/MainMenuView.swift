import SwiftUI

/// The main menu: painted ground, logo on the left, dancer in the middle, the
/// three round buttons in one corner and START in the other.
struct MainMenuView: View {
    @State var viewModel: MainMenuViewModel
    let settings: SettingsService
    let credits: CreditsProviding
    let scores: ScoreHistoryStoring
    let gameCenter: LeaderboardProviding

    @Environment(\.strings) private var strings
    @Environment(\.audio) private var audio

    var body: some View {
        GeometryReader { proxy in
            let layout = MenuLayout(size: proxy.size)

            ZStack {
                PaintTexture()
                Image("bg-yellow")
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                Image("dancer")
                    .resizable()
                    .scaledToFit()
                    .offset(x: layout.dancerOffset.width, y: layout.dancerOffset.height)
                    .frame(height: layout.dancerHeight)
                            .opacity(viewModel.isContentVisible ? 1 : 0)
                            .scaleEffect(
                                viewModel.isContentVisible ? layout.dancerBloom : 0.96,
                                anchor: .center
                            )
                            .animation(
                                .spring(response: 0.7, dampingFraction: 0.85),
                                value: viewModel.isContentVisible
                            )

                        chrome(layout: layout)
                        popupLayer
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .task { viewModel.onAppear() }
    }

    // MARK: - Chrome

    private func chrome(layout: MenuLayout) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                GameTitleView(layout: layout)
                    .offset(x: viewModel.isContentVisible ? -20 : -50, y:viewModel.isContentVisible ? 60 : 50)
                    .animation(.spring(response: 0.6, dampingFraction: 0.82), value: viewModel.isContentVisible)

                Spacer(minLength: 0)

                iconRow(layout: layout)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer(minLength: 0)
                Button(action: {
                    audio.play(.buttonTap)
                    viewModel.play()
                }) {
                    Text(strings[.menuPlay])
                        .font(.system(size: layout.scaled(34), weight: .bold, design: .rounded))
                        .tracking(layout.scaled(34) * 0.05)
                        .foregroundStyle(.white)
                        .padding(.horizontal, layout.scaled(72) * 0.65)
                        .frame(height: layout.scaled(72))
                        .background(Capsule().fill(Theme.Palette.indigo))
                }
                .buttonStyle(.plain)
                .opacity(viewModel.isContentVisible ? 1 : 0)
                .offset(x: -30, y: -40)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.12), value: viewModel.isContentVisible)
            }
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.vertical, layout.verticalPadding)
    }

    private func iconRow(layout: MenuLayout) -> some View {
        HStack(spacing: layout.iconSpacing) {
            ForEach(Array(MainMenuItem.allCases.enumerated()), id: \.element.id) { index, item in
                PaintedIconButton(symbol: item.symbolName, diameter: layout.iconDiameter) {
                    viewModel.select(item)
                }
                .accessibilityLabel(strings[item.titleKey])
                .opacity(viewModel.isContentVisible ? 1 : 0)
                .offset(y: viewModel.isContentVisible ? 0 : -40)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.78).delay(Double(index) * 0.06),
                    value: viewModel.isContentVisible
                )
            }
        }
        .offset(x:-24)
    }

    // MARK: - Popups

    @ViewBuilder
    private var popupLayer: some View {
        switch viewModel.activePopup {
        case .settings:
            SettingsPopupView(
                viewModel: SettingsViewModel(settings: settings),
                onClose: { viewModel.dismissPopup() }
            )
            .zIndex(1)

        case .credits:
            CreditsPopupView(
                viewModel: CreditsViewModel(repository: credits, settings: settings),
                onClose: { viewModel.dismissPopup() }
            )
            .zIndex(1)

        case .scores:
            LeaderboardPopupView(
                viewModel: LeaderboardViewModel(gameCenter: gameCenter),
                onClose: { viewModel.dismissPopup() }
            )
            .zIndex(1)

        case nil:
            EmptyView()
        }
    }
}


#Preview {
    let services = AppServices.preview()
    return MainMenuView(
        viewModel: MainMenuViewModel(audio: services.audio, onEnterGameplay: { _ in }),
        settings: services.settings,
        credits: services.credits,
        scores: services.scores,
        gameCenter: services.gameCenter
    )
    .environment(\.strings, services.settings.localizer)
}
