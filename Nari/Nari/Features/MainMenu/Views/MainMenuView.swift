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

    var body: some View {
        GeometryReader { proxy in
            let layout = MenuLayout(size: proxy.size)

            ZStack {
                PaintTexture()
                // Held to the stage in every orientation. A `scaledToFill`
                // image overflows the size it was offered, and an unclipped
                // one hands that overflowed size back to the ZStack as the
                // stack's own — which the `Spacer`-driven chrome then lays
                // itself out against, putting its corners outside the screen.
                //
                // Which way it overflows depends on the shape of the window
                // against this artwork's 1.43, so there is no orientation this
                // is safe to skip: an iPhone in portrait runs about 850 points
                // wide, an iPhone in landscape 200 points tall, an iPad in
                // landscape a hundred wide.
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
            .onTapGesture { viewModel.play() }
        }
        .ignoresSafeArea()
        .task { viewModel.onAppear() }
    }

    // MARK: - Chrome

    private func chrome(layout: MenuLayout) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                GameTitleView(layout: layout)
                    .offset(x: viewModel.isContentVisible ? 20 : -70, y:viewModel.isContentVisible ? 60 : 50)
                    .animation(.spring(response: 0.6, dampingFraction: 0.82), value: viewModel.isContentVisible)

                Spacer(minLength: 0)

                iconRow(layout: layout)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer(minLength: 0)
                Text("Tap to Start")
                    .font(.system(size: layout.scaled(46), weight: .bold, design: .rounded))
                    .foregroundStyle(.indigo)
                    .opacity(viewModel.isContentVisible ? 1 : 0)
                    .offset(x: -50, y:0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.12), value: viewModel.isContentVisible)
                    .modifier(BlinkingModifier())
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

struct BlinkingModifier: ViewModifier {
    @State private var isBlinking = false

    func body(content: Content) -> some View {
        content
            .opacity(isBlinking ? 0.4 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(), value: isBlinking)
            .onAppear { isBlinking = true }
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
