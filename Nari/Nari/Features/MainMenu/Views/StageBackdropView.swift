import SwiftUI

/// What sits behind the curtains: a dark warm stage with a soft spotlight and a
/// floor line. Also used by the gameplay placeholder so the curtain reveal and
/// the screen swap line up without a visible jump.
struct StageBackdropView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Palette.stageWarm, Theme.Palette.stageDeep],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Theme.Palette.curtainGold.opacity(0.22), .clear],
                center: .init(x: 0.5, y: 0.28),
                startRadius: 20,
                endRadius: 620
            )

            // Floor: a slightly lighter band with a warm reflection.
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [Theme.Palette.stageDeep, Theme.Palette.woodDark.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
            }

            // Vignette to keep attention in the middle of the stage.
            RadialGradient(
                colors: [.clear, .black.opacity(0.6)],
                center: .center,
                startRadius: 260,
                endRadius: 780
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    StageBackdropView()
}
