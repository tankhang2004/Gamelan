import AVFoundation
import Foundation
import OSLog
import ReplayKit

/// Records the screen for the length of a run — camera, HUD, and all —
/// using ReplayKit rather than compositing the camera feed and SwiftUI by
/// hand. Writing straight to a file this app owns (rather than the
/// completion-handler variant that hands back an `RPPreviewViewController`)
/// means the game can show its own playback and download button on the game
/// over screen instead of ReplayKit's system preview sheet.
@MainActor
final class SessionRecorder {
    private let recorder = RPScreenRecorder.shared()
    private var isRecording = false
    /// When capture actually began, and when the part worth keeping began.
    /// They differ because consent has to be asked for while the player is
    /// still at the iPad, which is several phases before the run starts.
    private var captureStartedAt: Date?
    private var contentStartedAt: Date?

    /// False on the simulator and on any device that has recording disabled
    /// (Screen Time restrictions, MDM), so the game over screen can fall back
    /// to the score-card-only download instead of waiting on a clip that will
    /// never arrive.
    var isAvailable: Bool { recorder.isAvailable }

    /// Starts once per run. Calling this again while already recording is a
    /// no-op on purpose: pausing and resuming re-enters `.playing`, and the
    /// whole run — not just the last leg of it — is what the player expects
    /// to find on the game over screen.
    func start() {
        guard recorder.isAvailable, !isRecording else { return }
        isRecording = true
        captureStartedAt = .now
        contentStartedAt = nil
        recorder.isMicrophoneEnabled = false
        recorder.startRecording { [weak self] error in
            guard let error else { return }
            Logger.recording.error("Could not start recording: \(error.localizedDescription)")
            Task { @MainActor in self?.isRecording = false }
        }
    }

    /// Marks the point the saved clip should begin at.
    ///
    /// Capture has to start early — ReplayKit puts its consent alert wherever
    /// `start()` is called, and the only moment the player is within reach of
    /// the iPad is before they walk back to their mark. So everything from
    /// there to the first scored frame is recorded and then cut off here,
    /// rather than handing the player a clip that opens on a minute of them
    /// shuffling into frame.
    func markContentStart() {
        guard isRecording, contentStartedAt == nil else { return }
        contentStartedAt = .now
    }

    /// Stops the run's recording and returns where the clip landed, or nil if
    /// nothing was recording or the write failed.
    func stop() async -> URL? {
        guard isRecording else { return nil }
        isRecording = false
        let leadIn = leadInSeconds
        captureStartedAt = nil
        contentStartedAt = nil

        // A fresh name every time, so a leftover file from a failed previous
        // write can never collide with this one.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        let raw: URL? = await withCheckedContinuation { continuation in
            recorder.stopRecording(withOutput: url) { error in
                if let error {
                    Logger.recording.error("Could not save recording: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: url)
                }
            }
        }

        guard let raw else { return nil }
        guard let leadIn, leadIn > 0.5 else { return raw }
        // Keeping the untrimmed clip on failure is deliberate: a slightly long
        // video is a far better outcome than no video at all.
        return await Self.trimmingLeadIn(leadIn, from: raw) ?? raw
    }

    /// How much of the capture happened before the run itself started.
    private var leadInSeconds: Double? {
        guard let captureStartedAt, let contentStartedAt else { return nil }
        return contentStartedAt.timeIntervalSince(captureStartedAt)
    }

    /// Re-exports the clip without its first `leadIn` seconds.
    private static func trimmingLeadIn(_ leadIn: Double, from source: URL) async -> URL? {
        let asset = AVURLAsset(url: source)
        guard let duration = try? await asset.load(.duration) else { return nil }

        let start = CMTime(seconds: leadIn, preferredTimescale: 600)
        guard start < duration else { return nil }

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            return nil
        }

        let trimmed = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        export.outputURL = trimmed
        export.outputFileType = .mp4
        export.timeRange = CMTimeRange(start: start, end: duration)

        await export.export()
        guard export.status == .completed else {
            Logger.recording.error("Could not trim recording: \(export.error?.localizedDescription ?? "unknown")")
            return nil
        }

        try? FileManager.default.removeItem(at: source)
        return trimmed
    }

    /// Discards whatever is mid-recording without keeping a file — the
    /// player left through Pause or the camera problem screen before ever
    /// reaching Game Over, so there is nothing to offer them anyway.
    func cancel() {
        guard isRecording else { return }
        isRecording = false
        captureStartedAt = nil
        contentStartedAt = nil
        recorder.stopRecording { _, _ in }
    }

    /// Throws the current run's footage away and opens a fresh clip for the
    /// next one. Awaits the stop rather than firing both off together:
    /// ReplayKit refuses a `startRecording` that lands while the previous
    /// recording is still closing, and Play Again does exactly that.
    func restart() async {
        if isRecording {
            isRecording = false
            captureStartedAt = nil
            contentStartedAt = nil
            await withCheckedContinuation { continuation in
                recorder.stopRecording { _, _ in continuation.resume() }
            }
        }
        start()
    }
}

private extension Logger {
    static let recording = Logger(subsystem: "com.yuknari.Nari", category: "recording")
}
