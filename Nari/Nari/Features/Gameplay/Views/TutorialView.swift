import SwiftUI

/// Shown right after the curtains open: a scrapbook page whose drawing changes
/// every second, explaining where to put the iPad and where to stand.
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
            Image("bg-yellow")
                .resizable()
                .scaledToFill()

//            Color.black.opacity(0.5)

            VStack(spacing: 18) {

                page

                Button(action: onStart) {
                    Text(strings[.tutorialStart])
                        .font(Theme.Fonts.label(34))
                        .tracking(34 * 0.05)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 84 * 0.55)
                        .frame(height: 84)
                        .background(Capsule().fill(Theme.Palette.indigo))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 26)

            VStack {
                HStack {
                    PaintedIconButton(symbol: "chevron.left", diameter: 78, action: onBack)
                        .offset(x: 40)
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

    /// The paper card. Frames are crossfaded rather than swapped so the change
    /// reads as one drawing being redrawn, not as a slideshow.
    private var page: some View {
        VStack(spacing: 10) {
            VideoView(name: "body-tracking-tutorial", fileExtension: "mp4")
                .aspectRatio(1920 / 1080, contentMode: .fit)
                .frame(maxWidth: 2000)
                .cornerRadius(16)
                .clipped()

            ZStack {
                ForEach(steps) { candidate in
                    Text(strings[candidate.captionKey])
                        .font(Theme.Fonts.body(24))
                        .foregroundStyle(Theme.Palette.pencil)
                        .multilineTextAlignment(.center)
                        .opacity(candidate == step ? 1 : 0)
                }
            }
            .frame(height: 100)
            .padding(.horizontal, 24)
        }
        .padding(22)
        .frame(maxWidth: 800)
//        .background(
//            Image("backset")
//                .resizable()
//                .scaledToFill().cornerRadius(16)
//        )
    }
}

#Preview {
    TutorialView(onStart: {}, onBack: {})
        .environment(\.strings, Localizer(language: .indonesian))
}
