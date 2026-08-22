import SwiftUI

/// The main menu: painted ground, logo on the left, dancer in the middle, the
/// three round buttons in one corner and START in the other.
struct MainMenuView: View {
    @State var viewModel: MainMenuViewModel
    let settings: SettingsService
    let credits: CreditsProviding
    let scores: ScoreHistoryStoring

    @Environment(\.strings) private var strings

    var body: some View {
        GeometryReader { proxy in
            let layout = MenuLayout(size: proxy.size)

            ZStack {
                PaintTexture()
                Image("bg-yellow")
                            .resizable()
                            .scaledToFill()
                Image("dancer")
                    .resizable()
                    .scaledToFit()
                    .offset(x:60, y:30)
                    .frame(height: layout.dancerHeight)
                            .opacity(viewModel.isContentVisible ? 1 : 0)
                            .scaleEffect(
                                viewModel.isContentVisible ? 1.4 : 0.96,
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
            ScoreHistoryPopupView(records: scores.records, onClose: { viewModel.dismissPopup() })
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
        scores: services.scores
    )
    .environment(\.strings, services.settings.localizer)
}
