import SwiftUI

/// The four menu plaques on the right of the stage, PLAY sized up as the hero.
struct MenuButtonStack: View {
    let layout: MenuLayout
    let isVisible: Bool
    let onSelect: (MainMenuItem) -> Void

    @Environment(\.strings) private var strings

    var body: some View {
        VStack(spacing: layout.buttonSpacing) {
            ForEach(Array(MainMenuItem.allCases.enumerated()), id: \.element.id) { index, item in
                Button {
                    onSelect(item)
                } label: {
                    label(for: item)
                }
                .buttonStyle(
                    PlaqueButtonStyle(emphasis: item.emphasis, height: height(for: item))
                )
                .accessibilityLabel(strings[item.titleKey])
                // Each plaque slides in from the right, one after the other.
                .offset(x: isVisible ? 0 : 90)
                .opacity(isVisible ? 1 : 0)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.82)
                        .delay(Double(index) * 0.07),
                    value: isVisible
                )
            }
        }
        .frame(width: layout.columnWidth)
    }

    private func height(for item: MainMenuItem) -> CGFloat {
        item.emphasis == .primary ? layout.primaryButtonHeight : layout.secondaryButtonHeight
    }

    private func label(for item: MainMenuItem) -> some View {
        let isPrimary = item.emphasis == .primary
        return HStack(spacing: layout.scaled(12)) {
            Image(systemName: item.symbolName)
                .font(.system(size: layout.scaled(isPrimary ? 30 : 20), weight: .bold))
            Text(strings[item.titleKey])
                .font(Theme.Fonts.label(layout.scaled(isPrimary ? 40 : 24)))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .foregroundStyle(isPrimary ? Theme.Palette.ink : Theme.Palette.parchment)
        .padding(.horizontal, 18)
    }
}

#Preview {
    GeometryReader { proxy in
        ZStack {
            StageBackdropView()
            MenuButtonStack(layout: MenuLayout(size: proxy.size), isVisible: true, onSelect: { _ in })
        }
    }
}
