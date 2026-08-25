import AVFoundation
import SwiftUI

/// Shown right after the curtains open: a video walkthrough explaining where
/// to put the iPad and where to stand, over the player's own reflection.
struct TutorialView: View {
    /// The live camera, once it has been switched on. Nil until permission is
    /// granted, and on a device with no camera at all.
    let session: AVCaptureSession?
    let onPreviewReady: (AVCaptureVideoPreviewLayer) -> Void
    /// True from the moment Ready is tapped until the camera is actually
    /// running. Switching the camera on is the slowest thing this screen
    /// does, and without something saying so the tap reads as a dropped one.
    var isStarting: Bool = false
    let onStart: () -> Void
    let onBack: () -> Void

    @Environment(\.strings) private var strings
    @Environment(\.audio) private var audio
    @State private var stepIndex = 0

    private let steps = TutorialStep.allCases
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var step: TutorialStep { steps[stepIndex] }

    var body: some View {
        ZStack {
            // The player's own reflection, dimmed so the walkthrough stays
            // readable over it. Seeing themselves here is half the lesson:
            // it shows immediately whether the iPad is far enough back.
            Group {
                if let session {
                    CameraPreviewView(session: session, onPreviewReady: onPreviewReady)
                } else {
                    Theme.Palette.ink
                }
            }
            .overlay(Color.black.opacity(0.5))

            // Everything below is sized against the stage rather than fixed,
            // because this screen has to survive an iPhone on its side: about
            // four hundred points of height for a 16:9 video, a caption, a
            // button, and a loading line.
            GeometryReader { proxy in
                let metrics = TutorialMetrics(size: proxy.size)

                VStack(spacing: metrics.spacing) {

                    videoPanel(metrics)

                    ZStack {
                        ForEach(steps) { candidate in
                            Text(strings[candidate.captionKey])
                                .font(Theme.Fonts.body(metrics.captionFont))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .opacity(candidate == step ? 1 : 0)
                        }
                    }
                    .frame(height: metrics.captionHeight)
                    .padding(.horizontal, 24)

                    Button(action: {
                        audio.play(.buttonTap)
                        onStart()
                    }) {
                        Text(strings[.tutorialStart])
                            .font(Theme.Fonts.label(metrics.buttonFont))
                            .tracking(metrics.buttonFont * 0.05)
                            .foregroundStyle(.white)
                            .padding(.horizontal, metrics.buttonHeight * 0.65)
                            .frame(height: metrics.buttonHeight)
                            .background(Capsule().fill(Theme.Palette.indigo))
                    }
                    .buttonStyle(.plain)
                    .disabled(isStarting)
                    .opacity(isStarting ? 0.55 : 1)

                    startingIndicator(metrics)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .padding(.top, metrics.topPadding)
            }

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

    /// The walkthrough, in a frame that is the video's own size.
    ///
    /// The rounding and the border go on the aspect-fitted video rather than
    /// on the box holding it. Put them outside the `maxWidth` frame and they
    /// draw around the *slot*, which stays as wide as the screen while the
    /// video shrinks to fit the height — which is why a phone on its side
    /// showed a full-width yellow rounded rectangle with a small video adrift
    /// in the middle of it.
    private func videoPanel(_ metrics: TutorialMetrics) -> some View {
        VideoView(name: "body-tracking-tutorial", fileExtension: "mp4")
            .aspectRatio(1920 / 1080, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: metrics.videoCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: metrics.videoCorner, style: .continuous)
                    .strokeBorder(Theme.Palette.ochre, lineWidth: metrics.videoBorder)
            )
            // Outermost, so it only ever bounds what the video may grow to.
            // Inside the rounding and the border it is the flexible frame that
            // gets decorated, and a flexible frame keeps the full width it was
            // offered while the video shrinks to fit the height.
            .frame(maxWidth: metrics.videoMaxWidth, maxHeight: metrics.videoMaxHeight)
    }

    /// Sits under the Ready button in a slot that is always there, so the
    /// button does not jump up the screen the moment it is pressed.
    private func startingIndicator(_ metrics: TutorialMetrics) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
            Text(strings[.tutorialPreparing])
                .font(Theme.Fonts.body(metrics.captionFont * 0.7))
                .foregroundStyle(.white.opacity(0.9))
        }
        .opacity(isStarting ? 1 : 0)
        .frame(height: metrics.indicatorHeight)
        .animation(.easeOut(duration: 0.2), value: isStarting)
        .accessibilityHidden(!isStarting)
    }
}

/// Sizes for the walkthrough, derived from the stage.
///
/// The screen was laid out against an iPad, where there is height to spare.
/// An iPhone on its side has about four hundred points for the whole stack, so
/// everything here shrinks together rather than the video being squeezed to
/// nothing by furniture that stayed full size.
struct TutorialMetrics {
    let spacing: CGFloat
    let topPadding: CGFloat
    let videoMaxWidth: CGFloat
    let videoMaxHeight: CGFloat
    let videoCorner: CGFloat
    let videoBorder: CGFloat
    let captionFont: CGFloat
    let captionHeight: CGFloat
    let buttonFont: CGFloat
    let buttonHeight: CGFloat
    let indicatorHeight: CGFloat

    init(size: CGSize) {
        let height = max(size.height, 1)
        // 1.0 on the 11-inch iPad this was drawn for, falling away on anything
        // shorter. Floored rather than left to shrink indefinitely, so the
        // caption stays readable and the button stays wide enough to hit.
        let scale = (height / 834).clamped(to: 0.42...1)

        spacing = 18 * scale
        topPadding = 50 * scale
        videoMaxWidth = min(1000, max(size.width - 48, 1))
        // The video takes what is left once the rest has had its share, so it
        // is the part that gives way on a short screen — never the button.
        videoMaxHeight = max(height * 0.46, 1)
        videoCorner = (24 * scale).clamped(to: 10...24)
        videoBorder = (16 * scale).clamped(to: 6...16)
        captionFont = (32 * scale).clamped(to: 17...32)
        captionHeight = (100 * scale).clamped(to: 46...100)
        buttonFont = (34 * scale).clamped(to: 20...34)
        buttonHeight = (72 * scale).clamped(to: 46...72)
        indicatorHeight = (34 * scale).clamped(to: 22...34)
    }
}

#Preview {
    TutorialView(session: nil, onPreviewReady: { _ in }, isStarting: true, onStart: {}, onBack: {})
        .environment(\.strings, Localizer(language: .indonesian))
}
