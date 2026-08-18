import SwiftUI
import UIKit

/// The game logo on the left of the stage. Swaps to the `GameTitle` image set
/// once the lettering artwork is added; the text version below is the stand-in.
struct GameTitleView: View {
    let layout: MenuLayout

    @Environment(\.strings) private var strings

    private var artwork: UIImage? { UIImage(named: "GameTitle") }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.scaled(14)) {
            if let artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: layout.titleWidth)
            } else {
                textLogo
            }

            Text(strings[.tagline])
                .font(Theme.Fonts.body(layout.scaled(17)))
                .foregroundStyle(Theme.Palette.parchment.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: layout.titleWidth, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Yuk, Nari!")
    }

    private var textLogo: some View {
        VStack(alignment: .leading, spacing: layout.scaled(-6)) {
            styled("Yuk,", size: layout.scaled(64))
                .rotationEffect(.degrees(-4))
            styled("Nari!", size: layout.scaled(104))
                .rotationEffect(.degrees(-2))
                .padding(.leading, layout.scaled(10))
        }
    }

    /// Layered fills give the lettering a gold face over a dark outline without
    /// needing custom glyph art.
    private func styled(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(Theme.Fonts.title(size))
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.Palette.goldTrimBright, Theme.Palette.curtainGold, Theme.Palette.curtainGoldDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Theme.Palette.curtainRedDeep, radius: 0, x: 3, y: 4)
            .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 8)
    }
}

#Preview {
    GeometryReader { proxy in
        ZStack {
            StageBackdropView()
            GameTitleView(layout: MenuLayout(size: proxy.size))
        }
    }
}
