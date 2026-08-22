import SwiftUI

/// The hand-lettered logo: a small tilted "Yuk," tucked above a big "Nari!"
/// running the other way. Uses the `GameTitle` image set once artwork is dropped
/// in, and draws the type version until then.
struct GameTitleView: View {
    let layout: MenuLayout

    var body: some View {
        if UIImage(named: "GameTitle") != nil {
            Image("GameTitle")
                .resizable()
                .scaledToFit()
                .frame(width: layout.titleWidth)
        } else {
            lettering
        }
    }

    private var lettering: some View {
        // The two words are laid out by hand rather than in a stack: the whole
        // point of the logo is that they lean against each other.
        ZStack(alignment: .topLeading) {
            Text("Yuk,")
                .font(Theme.Fonts.title(layout.scaled(52)))
                .rotationEffect(.degrees(10.6))
                .offset(x: layout.scaled(-6), y: 0)

            Text("Nari!")
                .font(Theme.Fonts.title(layout.scaled(150)))
                .rotationEffect(.degrees(-8.7))
                .offset(x: layout.scaled(18), y: layout.scaled(38))
        }
        .foregroundStyle(Theme.Palette.indigo)
        .shadow(color: Theme.Palette.ink.opacity(0.40), radius: 3, x: 12, y: 7)
        .frame(width: layout.titleWidth, height: layout.scaled(230), alignment: .topLeading)
    }
}

#Preview {
    GeometryReader { proxy in
        ZStack {
            PaintTexture()
            Image("bg")
                        .resizable()
                        .scaledToFill()
                        .frame(
                                        width: proxy.size.width,
                                        height: proxy.size.height
                                    )
                                    .clipped()
            GameTitleView(layout: MenuLayout(size: proxy.size))
        }
    }
    .ignoresSafeArea()
}
