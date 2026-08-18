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
            StageBackdropView()

            VStack(spacing: 18) {
                Text(strings[.tutorialTitle])
                    .font(Theme.Fonts.title(34))
                    .foregroundStyle(Theme.Palette.curtainGold)

                page

                Button(strings[.tutorialStart], action: onStart)
                    .buttonStyle(PlaqueButtonStyle(emphasis: .primary, height: 84))
                    .frame(width: 280)
                    .font(Theme.Fonts.label(30))
                    .foregroundStyle(Theme.Palette.ink)
            }
            .padding(.vertical, 26)

            VStack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.Palette.parchment)
                            .padding(16)
                            .background(Circle().fill(Color.black.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
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
            ZStack {
                ForEach(steps) { candidate in
                    TutorialSketchView(step: candidate)
                        .opacity(candidate == step ? 1 : 0)
                }
            }
            .frame(maxWidth: 520, maxHeight: .infinity)

            ZStack {
                ForEach(steps) { candidate in
                    Text(strings[candidate.captionKey])
                        .font(Theme.Fonts.body(19))
                        .foregroundStyle(Theme.Palette.pencil)
                        .multilineTextAlignment(.center)
                        .opacity(candidate == step ? 1 : 0)
                }
            }
            .frame(height: 58)
            .padding(.horizontal, 24)

            pageDots
        }
        .padding(22)
        .frame(maxWidth: 620)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Palette.paper)
                .shadow(color: .black.opacity(0.5), radius: 22, y: 10)
        )
        .overlay(tapeStrips)
        .rotationEffect(.degrees(-0.7))
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(steps) { candidate in
                Circle()
                    .fill(candidate == step ? Theme.Palette.pencil : Theme.Palette.pencil.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
    }

    /// Bits of tape at the corners, the one thing that makes a rectangle read
    /// as a page stuck into a scrapbook.
    private var tapeStrips: some View {
        ZStack {
            tape.rotationEffect(.degrees(-38)).offset(x: -285, y: -128)
            tape.rotationEffect(.degrees(34)).offset(x: 285, y: 128)
        }
        .allowsHitTesting(false)
    }

    private var tape: some View {
        Rectangle()
            .fill(Theme.Palette.curtainGold.opacity(0.45))
            .frame(width: 84, height: 26)
            .overlay(Rectangle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
    }
}

#Preview {
    TutorialView(onStart: {}, onBack: {})
        .environment(\.strings, Localizer(language: .indonesian))
}
