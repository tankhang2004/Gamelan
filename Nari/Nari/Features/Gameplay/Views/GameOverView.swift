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
    let onRetry: () -> Void
    let onMenu: () -> Void

    @Environment(\.strings) private var strings
    @State private var landed = false
    @State private var downloadStatus: String?

    private var shareMessage: String {
        String(format: strings[.gameOverShareMessage], score)
    }

    var body: some View {
        ZStack {
            Theme.Palette.ink.opacity(0.55)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    closeButton
                }

                Spacer()

                HStack(alignment: .center, spacing: 48) {
                    scoreCard
                    videoPlaybackPlaceholder
                }

                Spacer()

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
        }
        .onAppear {
            withAnimation(Theme.Motion.cueDrop) { landed = true }
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        Button(action: onMenu) {
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

    private var scoreCard: some View {
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

            scoreBadge
                .offset(x: 22, y: 148)
        }
        .padding(.bottom, 30)
    }

    private var outlinedTitle: some View {
        Text(strings[.gameOverYourScore])
            .font(Theme.Fonts.title(42))
            .foregroundStyle(Theme.Palette.indigo)
            .shadow(color: .white, radius: 0, x: 2, y: 0)
            .shadow(color: .white, radius: 0, x: -2, y: 0)
            .shadow(color: .white, radius: 0, x: 0, y: 2)
            .shadow(color: .white, radius: 0, x: 0, y: -2)
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

    /// Stands in for the recorded run until the recording pipeline lands.
    private var videoPlaybackPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.Palette.ink.opacity(0.3))
            .frame(width: 320, height: 240)
            .overlay(
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white, lineWidth: 3)
            )
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 20) {
            Button(action: onRetry) {
                Label(strings[.gameOverRetry], systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(pillStyle)

            ShareLink(item: shareMessage) {
                Label(strings[.gameOverShare], systemImage: "square.and.arrow.up")
            }
            .buttonStyle(pillStyle)

            Button(action: saveScoreCard) {
                Label(strings[.gameOverDownload], systemImage: "arrow.down.to.line")
            }
            .buttonStyle(pillStyle)
        }
    }

    private var pillStyle: PaintedButtonStyle {
        PaintedButtonStyle(fill: Theme.Palette.cueOrange, textColor: .white, borderColor: .white, height: 72, fontSize: 24)
    }

    // MARK: - Download

    @MainActor
    private func saveScoreCard() {
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

#Preview {
    ZStack {
        GameOverView(
            score: 21983,
            survived: "01:45",
            isBest: true,
            bestScore: 18420,
            onRetry: {},
            onMenu: {}
        )
    }
    .ignoresSafeArea()
    .environment(\.strings, Localizer(language: .english))
}
