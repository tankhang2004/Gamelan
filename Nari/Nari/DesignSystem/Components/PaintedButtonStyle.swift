import SwiftUI

/// The indigo pill with a heavy ink outline that every primary action uses.
struct PaintedButtonStyle: ButtonStyle {
    var fill: Color = Theme.Palette.indigo
    var textColor: Color = Theme.Palette.cream
    var height: CGFloat = 84
    var fontSize: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.label(fontSize))
            .tracking(fontSize * 0.05)
            .foregroundStyle(textColor)
            .padding(.horizontal, height * 0.55)
            .frame(height: height)
            .background {
                // The drop shadow sits on the pill only. Shadowing the whole
                // label would print a second copy of the word behind the first.
                Capsule()
                    .fill(configuration.isPressed ? fill.opacity(0.82) : fill)
                    .shadow(color: Theme.Palette.ink.opacity(0.4), radius: 0, x: 0, y: configuration.isPressed ? 2 : 7)
            }
            .overlay(Capsule().strokeBorder(Theme.Palette.ink, lineWidth: height * 0.06))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A round icon button, used for the settings / info / scores row in the corner
/// of the menu.
struct PaintedIconButton: View {
    let symbol: String
    var diameter: CGFloat = 78
    var fill: Color = Theme.Palette.cueOrange
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: diameter * 0.46, weight: .semibold))
                .foregroundStyle(Theme.Palette.cream)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(fill))
                .overlay(Circle().strokeBorder(Theme.Palette.ink, lineWidth: diameter * 0.07))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaintedIconButton(symbol: <#T##String#>, diameter: <#T##CGFloat#>, fill: <#T##Color#>, action: <#T##() -> Void#>)
}
