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
        recorder.isMicrophoneEnabled = false
        recorder.startRecording { [weak self] error in
            guard let error else { return }
            Logger.recording.error("Could not start recording: \(error.localizedDescription)")
            Task { @MainActor in self?.isRecording = false }
        }
    }

    /// Stops the run's recording and returns where the clip landed, or nil if
    /// nothing was recording or the write failed.
    func stop() async -> URL? {
        guard isRecording else { return nil }
        isRecording = false

        // A fresh name every time, so a leftover file from a failed previous
        // write can never collide with this one.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        return await withCheckedContinuation { continuation in
            recorder.stopRecording(withOutput: url) { error in
                if let error {
                    Logger.recording.error("Could not save recording: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: url)
                }
            }
        }
    }

    /// Discards whatever is mid-recording without keeping a file — the
    /// player left through Pause or the camera problem screen before ever
    /// reaching Game Over, so there is nothing to offer them anyway.
    func cancel() {
        guard isRecording else { return }
        isRecording = false
        recorder.stopRecording { _, _ in }
    }

    /// Throws the current run's footage away and opens a fresh clip for the
    /// next one. Awaits the stop rather than firing both off together:
    /// ReplayKit refuses a `startRecording` that lands while the previous
    /// recording is still closing, and Play Again does exactly that.
    func restart() async {
        if isRecording {
            isRecording = false
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
