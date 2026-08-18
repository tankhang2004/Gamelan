import SwiftUI

/// The main menu stage: backdrop, curtains, dancer, logo, menu plaques, popups.
struct MainMenuView: View {
    @State var viewModel: MainMenuViewModel
    let settings: SettingsService
    let credits: CreditsProviding

    var body: some View {
        GeometryReader { proxy in
            let layout = MenuLayout(size: proxy.size)

            ZStack {
                StageBackdropView()

                CurtainView(phase: viewModel.curtainPhase, valanceHeight: layout.valanceHeight)

                content(layout: layout, in: proxy.size)
                    .padding(.top, layout.valanceHeight * 0.55)

                popupLayer
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .task { viewModel.onAppear() }
    }

    // MARK: - Stage content

    private func content(layout: MenuLayout, in size: CGSize) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                DancerView(height: layout.dancerHeight)
            }
            .padding(.bottom, size.height * 0.06)
            .opacity(viewModel.isContentVisible ? 1 : 0)
            .scaleEffect(viewModel.isContentVisible ? 1 : 0.94, anchor: .bottom)

            HStack(alignment: .center, spacing: 24) {
                GameTitleView(layout: layout)
                    .opacity(viewModel.isContentVisible ? 1 : 0)
                    .offset(x: viewModel.isContentVisible ? 0 : -60)
                    .animation(.spring(response: 0.6, dampingFraction: 0.82), value: viewModel.isContentVisible)

                Spacer(minLength: 0)

                MenuButtonStack(layout: layout, isVisible: viewModel.isContentVisible) { item in
                    viewModel.select(item)
                }
            }
            .padding(.horizontal, layout.horizontalPadding)
        }
        .animation(Theme.Motion.contentFade, value: viewModel.isContentVisible)
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
        credits: services.credits
    )
    .environment(\.strings, services.settings.localizer)
}
