import AVKit
import Photos
import SwiftUI

/// The end of a run: score on the left, a playback of the run on the right,
/// and the ways to replay, share, or save it. Kept neutral on purpose — this
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
        ZStack {
            Theme.Palette.ink.opacity(0.55)
                .ignoresSafeArea()

            // The summary sits as one vertically centred block, so the gap
            // above it always matches the gap below however tall the video
            // turns out to be. The close button is deliberately outside it —
            // it belongs to the corner of the screen, not to the group.
            VStack(spacing: 44) {
                HStack(alignment: .center, spacing: 48) {
                    scoreCard
                    videoPlayback
                }

                VStack(spacing: 10) {
                    actionRow
                    if let downloadStatus {
                        Text(downloadStatus)
                            .font(Theme.Fonts.body(15))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .padding(32)
            .opacity(landed ? 1 : 0)
            .scaleEffect(landed ? 1 : 0.9)

            VStack {
                HStack {
                    Spacer()
                    closeButton
                }
                Spacer()
            }
            .padding(32)
            .opacity(landed ? 1 : 0)
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

    private var closeButton: some View {
        HandHoverButton(action: onMenu) {
            Image(systemName: "xmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.Palette.ink)
                .frame(width: 64, height: 64)
                .background(Circle().fill(.white))
                .shadow(color: Theme.Palette.ink.opacity(0.3), radius: 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Score

    /// Laid out as a stack rather than with hand-placed offsets, so the badge
    /// stays centred under the score whatever it ends up saying — "New High
    /// Score!" and "Best score: 18420" are very different widths.
    private var scoreCard: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                Image("bg-white")
                    .resizable()
                    .frame(width: 340, height: 150)
                    .overlay(
                        Text(score.formatted())
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.Palette.ink)
                    )

                outlinedTitle
                    .offset(x: 6, y: -28)
            }

            scoreBadge
        }
    }

    private var outlinedTitle: some View {
        Text(strings[.gameOverYourScore])
            .font(Theme.Fonts.title(42))
            .foregroundStyle(Theme.Palette.indigo)
            .outlined(color: .white)
    }
 
    private var scoreBadge: some View {
        Text(isBest
             ? strings[.gameOverNewHighScore]
             : "\(strings[.gameOverBestScoreLabel]): \(bestScore)")
            .font(Theme.Fonts.label(36))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 36)
            .padding(.vertical, 22)
            .background(
                Image("bg-green")
                    .resizable()
            )
    }

    // MARK: - Playback

    @ViewBuilder
    private var videoPlayback: some View {
        if let player {
            VideoPlayer(player: player)
                .frame(width: 320, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white, lineWidth: 3)
                )
        } else {
            videoPlaybackPlaceholder
        }
    }

    /// Shown until the clip is ready, and left up permanently on a device
    /// that never produces one (the simulator, or recording disabled).
    private var videoPlaybackPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.Palette.ink.opacity(0.3))
            .frame(width: 320, height: 240)
            .overlay(
                Group {
                    if isPreparingVideo {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.4)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white, lineWidth: 3)
            )
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 20) {
            HandHoverButton(action: onRetry) {
                Label(strings[.gameOverRetry], systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(pillStyle)

            HandHoverButton(action: { isSharePresented = true }) {
                Label(strings[.gameOverShare], systemImage: "square.and.arrow.up")
            }
            .buttonStyle(pillStyle)

            HandHoverButton(action: saveRecording) {
                Label(strings[.gameOverDownload], systemImage: "arrow.down.to.line")
            }
            .buttonStyle(pillStyle)
        }
    }

    private var pillStyle: PaintedButtonStyle {
        PaintedButtonStyle(fill: Theme.Palette.cueOrange, textColor: .white, borderColor: .white, height: 72, fontSize: 24)
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
        let renderer = ImageRenderer(content: scoreCard.padding(20).background(Theme.Palette.ochreLight))
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

/// A plain `UIActivityViewController` wrapper, standing in for `ShareLink`
/// here because `ShareLink` has no way to be opened programmatically — and a
/// `HandHoverButton` needs to open it from a completed hover, not only a tap.
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
