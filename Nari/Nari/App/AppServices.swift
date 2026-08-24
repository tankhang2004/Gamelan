import Foundation

/// Composition root. Builds the long-lived services once and hands them to the
/// view models, so nothing in the app reaches for a global singleton.
@MainActor
final class AppServices {
    let audio: AudioServicing
    let settings: SettingsService
    let credits: CreditsProviding
    let poses: PoseProviding
    let scores: ScoreHistoryStoring
    let gameCenter: LeaderboardProviding

    init(
        store: SettingsStoring = UserDefaultsSettingsStore(),
        audio: AudioServicing = NariAudioService(),
        credits: CreditsProviding = StaticCreditsRepository(),
        poses: PoseProviding = PoseRepository(),
        scores: ScoreHistoryStoring = UserDefaultsScoreHistoryStore(),
        gameCenter: LeaderboardProviding = GameCenterService()
    ) {
        self.audio = audio
        self.settings = SettingsService(store: store, audio: audio)
        self.credits = credits
        self.poses = poses
        self.scores = scores
        self.gameCenter = gameCenter
    }

    /// A fresh pose source per session, so a cancelled session never leaves the
    /// camera running. The simulator has no camera, so it gets a fake dancer.
    func makeBodyPoseSource() -> BodyPoseSource {
        #if targetEnvironment(simulator)
        SimulatedBodyPoseSource()
        #else
        CameraBodyPoseService()
        #endif
    }

    /// Throwaway graph for SwiftUI previews: nothing is persisted.
    static func preview() -> AppServices {
        AppServices(
            store: InMemorySettingsStore(),
            audio: SilentAudioService(),
            scores: InMemoryScoreHistoryStore(),
            gameCenter: NoopLeaderboardService()
        )
    }
}
