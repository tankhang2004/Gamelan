import SwiftUI

/// Shown right after the curtains open: a video walkthrough explaining where
/// to put the iPad and where to stand.
struct TutorialView: View {
    let onStart: () -> Void
    let onBack: () -> Void

    @Environment(\.strings) private var strings
    @State private var stepIndex = 0

    private let steps = TutorialStep.allCases
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var step: TutorialStep { steps[stepIndex] }

    var body: some View {
        ZStack {
            // Stands in for the live camera mirror until the recording
            // pipeline lands — swap for CameraPreviewView then.
            Theme.Palette.ink
                .overlay(Color.black.opacity(0.5))

            VStack(spacing: 18) {

                VideoView(name: "body-tracking-tutorial", fileExtension: "mp4")
                    .aspectRatio(1920 / 1080, contentMode: .fit)
                    .frame(maxWidth: 1000)
                    .cornerRadius(24)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Theme.Palette.ochre, lineWidth: 16)
                    )

                ZStack {
                    ForEach(steps) { candidate in
                        Text(strings[candidate.captionKey])
                            .font(Theme.Fonts.body(32))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .opacity(candidate == step ? 1 : 0)
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 24)

                Button(action: onStart) {
                    Text(strings[.tutorialStart])
                        .font(Theme.Fonts.label(34))
                        .tracking(34 * 0.05)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 84 * 0.55)
                        .frame(height: 72)
                        .background(Capsule().fill(Theme.Palette.indigo))
                }
                .buttonStyle(.plain)
            }
            .padding(.top,50)

            VStack {
                HStack {
                    PaintedIconButton(symbol: "chevron.left", diameter: 64, action: onBack)
                        .offset(x: 40, y:24)
                    Spacer()
                }
                Spacer()
            }
            .padding(28)
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.45)) {
                stepIndex = (stepIndex + 1) % steps.count
            }
        }
        .task {
            #if DEBUG
            guard DebugLaunchOptions.autoStartsSession else { return }
            try? await Task.sleep(for: .seconds(1.5))
            onStart()
            #endif
        }
    }
}

#Preview {
    TutorialView(onStart: {}, onBack: {})
        .environment(\.strings, Localizer(language: .indonesian))
}
