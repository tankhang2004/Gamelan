import AVKit
import Photos
import SwiftUI

/// The end of a run: score on the left, a playback of the run on the right,
/// and the ways to replay, share, or save it.
///
/// Plain taps, not `HandHoverButton`s. Hand control is for a player standing
/// several metres back mid-dance; here they walk *up* to the iPad to hit
/// Download, and on the way their wrists sweep across the buttons. Play Again
/// would fire from the approach itself, throwing away the run and the
/// recording they came over to save. Kept neutral on purpose — this
/// is a session summary, not a win or lose screen.
struct GameOverView: View {
    let score: Int
    let survived: String
    let isBest: Bool
    let bestScore: Int
    /// Where `GameplayViewModel` wrote this run's screen recording, once
    /// `SessionRecorder` finishes encoding it. Nil while that is still in
    /// flight, and forever nil on a device that cannot record at all.
    let videoURL: URL?
    let isPreparingVideo: Bool
    let onRetry: () -> Void
    let onMenu: () -> Void

    @Environment(\.strings) private var strings
    @State private var landed = false
    @State private var downloadStatus: String?
    @State private var isSharePresented = false
    @State private var player: AVPlayer?

    private var shareMessage: String {
        String(format: strings[.gameOverShareMessage], score)
    }

    private var shareItems: [Any] {
        videoURL.map { [shareMessage, $0] } ?? [shareMessage]
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = GameOverMetrics(size: proxy.size)

            ZStack {
                Theme.Palette.ink.opacity(0.55)
                    .ignoresSafeArea()

                // The summary sits as one vertically centred block, so the gap
                // above it always matches the gap below however tall the video
                // turns out to be. The close button is deliberately outside it —
                // it belongs to the corner of the screen, not to the group.
                VStack(spacing: metrics.blockSpacing) {
                    summaryPanels(metrics)

                    VStack(spacing: 10) {
                        actions(metrics)
                        if let downloadStatus {
                            Text(downloadStatus)
                                .font(Theme.Fonts.body(15))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .padding(metrics.outerPadding)
                .opacity(landed ? 1 : 0)
                .scaleEffect(landed ? 1 : 0.9)

                VStack {
                    HStack {
                        Spacer()
                        closeButton(metrics)
                    }
                    Spacer()
                }
                .padding(metrics.outerPadding)
                .opacity(landed ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(Theme.Motion.cueDrop) { landed = true }
        }
        .sheet(isPresented: $isSharePresented) {
            ActivityShareSheet(items: shareItems)
        }
        .onAppear { attachPlayerIfNeeded() }
        .onChange(of: videoURL) { _, _ in attachPlayerIfNeeded() }
    }

    private func attachPlayerIfNeeded() {
        guard let videoURL, player == nil else { return }
        player = AVPlayer(url: videoURL)
    }

    // MARK: - Close

    private func closeButton(_ metrics: GameOverMetrics) -> some View {
        Button(action: onMenu) {
            Image(systemName: "xmark")
                .font(.system(size: metrics.closeDiameter * 0.38, weight: .bold))
                .foregroundStyle(Theme.Palette.ink)
                .frame(width: metrics.closeDiameter, height: metrics.closeDiameter)
                .background(Circle().fill(.white))
                .shadow(color: Theme.Palette.ink.opacity(0.3), radius: 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Panels

    /// The score and the run's video, side by side where there is width for
    /// it and one above the other where there is not.
    @ViewBuilder
    private func summaryPanels(_ metrics: GameOverMetrics) -> some View {
        if metrics.isStacked {
            VStack(spacing: metrics.pairSpacing) {
                scoreCard(metrics)
                videoPlayback(metrics)
            }
        } else {
            HStack(alignment: .center, spacing: metrics.pairSpacing) {
                scoreCard(metrics)
                videoPlayback(metrics)
            }
        }
    }

    // MARK: - Score

    /// Laid out as a stack rather than with hand-placed offsets, so the badge
    /// stays centred under the score whatever it ends up saying — "New High
    /// Score!" and "Best score: 18420" are very different widths.
    private func scoreCard(_ metrics: GameOverMetrics) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                Image("bg-white")
                    .resizable()
                    .frame(width: metrics.cardWidth, height: metrics.cardHeight)
                    .overlay(
                        Text(score.formatted())
                            .font(.system(size: metrics.scoreFont, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.Palette.ink)
                    )

                outlinedTitle(metrics)
                    .offset(x: 6, y: -metrics.titleOffset)
            }
            // The title is drawn outside the card it sits on, by an offset,
            // which means it costs the stack no height at all. On an iPad
            // that only ever ate into space there was plenty of; on a phone
            // in portrait the block is centred to the point, and the title
            // was the part that went off the top edge. This reserves it.
            .padding(.top, metrics.titleOffset)

            scoreBadge(metrics)
        }
    }

    private func outlinedTitle(_ metrics: GameOverMetrics) -> some View {
        Text(strings[.gameOverYourScore])
            .font(Theme.Fonts.title(metrics.titleFont))
            .foregroundStyle(.white)
            .shadow(color: Theme.Palette.ink.opacity(0.85), radius: 8, y: 5)
            .shadow(color: Theme.Palette.ink.opacity(0.5), radius: 2, y: 2)
    }

    private func scoreBadge(_ metrics: GameOverMetrics) -> some View {
        Text(isBest
             ? strings[.gameOverNewHighScore]
             : "\(strings[.gameOverBestScoreLabel]): \(bestScore)")
            .font(Theme.Fonts.label(metrics.badgeFont))
            .tracking(0.5)
            .foregroundStyle(.white)
            // One line, shrinking to fit rather than wrapping: the paint
            // behind it is a fixed brushstroke, and a second line simply
            // grows out through the top and bottom of it.
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .multilineTextAlignment(.center)
            .padding(.horizontal, metrics.badgeHPadding)
            .padding(.vertical, metrics.badgeVPadding)
            .frame(maxWidth: metrics.cardWidth)
            .background(
                Image("bg-green")
                    .resizable()
            )
    }

    // MARK: - Playback

    @ViewBuilder
    private func videoPlayback(_ metrics: GameOverMetrics) -> some View {
        if let player {
            VideoPlayer(player: player)
                .frame(width: metrics.videoWidth, height: metrics.videoHeight)
                .clipShape(RoundedRectangle(cornerRadius: metrics.videoCorner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.videoCorner, style: .continuous)
                        .strokeBorder(.white, lineWidth: 3)
                )
        } else {
            videoPlaybackPlaceholder(metrics)
        }
    }

    /// Shown until the clip is ready, and left up permanently on a device
    /// that never produces one (the simulator, or recording disabled).
    private func videoPlaybackPlaceholder(_ metrics: GameOverMetrics) -> some View {
        RoundedRectangle(cornerRadius: metrics.videoCorner, style: .continuous)
            .fill(Theme.Palette.ink.opacity(0.3))
            .frame(width: metrics.videoWidth, height: metrics.videoHeight)
            .overlay(
                Group {
                    if isPreparingVideo {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.4)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: metrics.videoHeight * 0.2))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.videoCorner, style: .continuous)
                    .strokeBorder(.white, lineWidth: 3)
            )
    }

    // MARK: - Actions

    /// A row where three pills fit across, a column where they do not. Three
    /// full-width pills is also the friendlier shape for the way these are
    /// really pressed — a hand held over one from across the room.
    @ViewBuilder
    private func actions(_ metrics: GameOverMetrics) -> some View {
        if metrics.isStacked {
            VStack(spacing: metrics.actionSpacing) {
                actionButtons(metrics)
            }
            .frame(width: metrics.actionWidth)
        } else {
            HStack(spacing: metrics.actionSpacing) {
                actionButtons(metrics)
            }
        }
    }

    @ViewBuilder
    private func actionButtons(_ metrics: GameOverMetrics) -> some View {
        // Play Again is the one thing most players came to this screen for,
        // so it is the one pill that is not the same orange as its neighbours.
        Button(action: onRetry) {
            actionLabel(strings[.gameOverRetry], symbol: "arrow.counterclockwise", metrics)
        }
        .buttonStyle(pillStyle(metrics, fill: Theme.Palette.indigo))

        Button(action: { isSharePresented = true }) {
            actionLabel(strings[.gameOverShare], symbol: "square.and.arrow.up", metrics)
        }
        .buttonStyle(pillStyle(metrics))

        Button(action: saveRecording) {
            actionLabel(strings[.gameOverDownload], symbol: "arrow.down.to.line", metrics)
        }
        .buttonStyle(pillStyle(metrics))
    }

    /// Stretched in a column so the three pills share one width — a stack of
    /// pills each cut to its own word reads as three unrelated things.
    private func actionLabel(_ text: String, symbol: String, _ metrics: GameOverMetrics) -> some View {
        Label(text, systemImage: symbol)
            .lineLimit(1)
            .frame(maxWidth: metrics.isStacked ? .infinity : nil)
    }

    private func pillStyle(_ metrics: GameOverMetrics, fill: Color = Theme.Palette.cueOrange) -> PaintedButtonStyle {
        PaintedButtonStyle(
            fill: fill,
            textColor: .white,
            borderColor: .white,
            height: metrics.buttonHeight,
            fontSize: metrics.buttonFont
        )
    }

    // MARK: - Download

    /// Saves the run's video when one exists; falls back to the score card
    /// image on a device that could never record one in the first place.
    @MainActor
    private func saveRecording() {
        guard let videoURL else {
            saveScoreCardImage()
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in showDownloadStatus(strings[.gameOverDownloadDenied]) }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            } completionHandler: { success, _ in
                Task { @MainActor in
                    showDownloadStatus(success ? strings[.gameOverDownloadSaved] : strings[.gameOverDownloadDenied])
                }
            }
        }
    }

    @MainActor
    private func saveScoreCardImage() {
        let renderer = ImageRenderer(content: scoreCard(.reference).padding(20).background(Theme.Palette.ochreLight))
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else { return }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in showDownloadStatus(strings[.gameOverDownloadDenied]) }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                Task { @MainActor in
                    showDownloadStatus(success ? strings[.gameOverDownloadSaved] : strings[.gameOverDownloadDenied])
                }
            }
        }
    }

    private func showDownloadStatus(_ text: String) {
        withAnimation { downloadStatus = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { downloadStatus = nil }
        }
    }
}

/// Sizes for the summary, derived from the stage.
///
/// The screen was drawn against an iPad in landscape, where the score card and
/// the run's video sit happily side by side over a row of three pills. A phone
/// in portrait has the width for neither: the video went off one edge and
/// Download off the other, and Play Again broke onto two lines trying to fit
/// what was left. So a portrait stage stacks the two panels, turns the row
/// into a column, and everything shrinks together to whatever room there
/// actually is — rather than one part holding its drawn size while the rest
/// is squeezed around it.
struct GameOverMetrics {
    /// Portrait puts the video under the score and the pills in a column;
    /// landscape keeps the pairing and the row this screen was drawn as.
    let isStacked: Bool
    let outerPadding: CGFloat
    /// Between the panels and the actions under them.
    let blockSpacing: CGFloat
    /// Between the score card and the video, whichever way they are arranged.
    let pairSpacing: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let scoreFont: CGFloat
    let titleFont: CGFloat
    let titleOffset: CGFloat
    let badgeFont: CGFloat
    let badgeHPadding: CGFloat
    let badgeVPadding: CGFloat
    let videoWidth: CGFloat
    let videoHeight: CGFloat
    let videoCorner: CGFloat
    let buttonHeight: CGFloat
    let buttonFont: CGFloat
    let actionSpacing: CGFloat
    /// The shared width of a column of pills. Nil in the row, where each pill
    /// is still cut to its own word.
    let actionWidth: CGFloat?
    let closeDiameter: CGFloat

    /// The layout at the size it was drawn at, for rendering the score card
    /// into a photo: what gets saved to the library should not depend on which
    /// way the phone happened to be held when the run ended.
    static let reference = GameOverMetrics(size: CGSize(width: 1194, height: 834))

    init(size: CGSize) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let stacked = height > width
        isStacked = stacked

        let padding: CGFloat = 32
        let room = CGSize(
            width: max(width - padding * 2, 1),
            height: max(height - padding * 2, 1)
        )

        // What each arrangement wants at full size. The heights carry the
        // spacings and the title's overhang above the card as well as the
        // panels, so the scale below is measured against the whole block
        // rather than against its largest piece.
        let wanted = stacked
            ? CGSize(width: 340, height: 860)
            : CGSize(width: 708, height: 420)

        // Shrunk to whichever edge runs out first, and never grown past the
        // size this was drawn at — an iPad has room to spare and does not need
        // a bigger score card, it needs the same one with more air around it.
        let scale = min(
            room.width / wanted.width,
            room.height / wanted.height
        ).clamped(to: 0.45...1)

        outerPadding = padding * scale
        blockSpacing = 44 * scale
        pairSpacing = (stacked ? 24 : 48) * scale
        cardWidth = 340 * scale
        cardHeight = 150 * scale
        scoreFont = 56 * scale
        titleFont = 42 * scale
        titleOffset = 28 * scale
        badgeFont = 27 * scale
        badgeHPadding = 36 * scale
        badgeVPadding = 22 * scale
        videoWidth = 320 * scale
        videoHeight = 240 * scale
        videoCorner = 16 * scale
        buttonHeight = 72 * scale
        buttonFont = 24 * scale
        actionSpacing = (stacked ? 12 : 20) * scale
        actionWidth = stacked ? min(340 * scale, room.width) : nil
        closeDiameter = (64 * scale).clamped(to: 44...64)
    }
}

/// A plain `UIActivityViewController` wrapper, standing in for `ShareLink`
/// here because `ShareLink` has no way to be opened programmatically — and a
/// The share sheet is opened from a plain tap, so it needs presenting rather
/// than a `ShareLink`.
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    ZStack {
        GameOverView(
            score: 21983,
            survived: "01:45",
            isBest: true,
            bestScore: 18420,
            videoURL: nil,
            isPreparingVideo: false,
            onRetry: {},
            onMenu: {}
        )
    }
    .ignoresSafeArea()
    .environment(\.strings, Localizer(language: .english))
}
