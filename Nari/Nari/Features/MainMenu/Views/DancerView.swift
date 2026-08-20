import SwiftUI

/// The painted dancer that fills the middle of the menu. Falls back to a
/// silhouette in a dashed frame until the artwork is dropped into the `Dancer`
/// image set.
struct DancerView: View {
    let height: CGFloat
    /// A slow sway, so the menu is never completely still.
    @State private var sway = false

    var body: some View {
        Group {
            if UIImage(named: "Dancer") != nil {
                Image("Dancer")
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
            }
        }
        .frame(height: height)
        .rotationEffect(.degrees(sway ? 1.1 : -1.1), anchor: .bottom)
        .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: sway)
        .onAppear { sway = true }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    Theme.Palette.ink.opacity(0.45),
                    style: StrokeStyle(lineWidth: 3, dash: [12, 10])
                )

            VStack(spacing: 14) {
                Image(systemName: "figure.dance")
                    .font(.system(size: height * 0.30, weight: .light))
                Text("Dancer")
                    .font(Theme.Fonts.body(height * 0.045))
            }
            .foregroundStyle(Theme.Palette.ink.opacity(0.5))
        }
        .aspectRatio(0.72, contentMode: .fit)
    }
}
