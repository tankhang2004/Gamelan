import AVFoundation
import Foundation

/// Every sound the game asks for, one case per moment in the design's cue list.
/// Concrete files are wired up later; the cases exist now so call sites do not
/// change when the audio assets land.
enum SoundEffect: String, Sendable {
    case buttonTap
    case popupOpen
    case popupClose
    case calibrationComplete

    case ngayogCycle
    /// A foot landing during the march.
    case footStep
    /// A frangipani opening somewhere in the room.
    case coinSpawned
    /// A frangipani picked before it wilted away.
    case coinCollected
    case squatCue
    case squatHit
    case squatMiss
    /// Stood up while the wave was still passing.
    case squatBroken
    case squatHeld
    /// The gong that marks the music cutting out for a Freeze.
    case freezeCue
    /// The pose locked in and the hold began.
    case freezeLocked
    case freezeHeld
    case freezeBroken
    case freezeFailed
    case energyLow
    /// A Leyak beginning its dive.
    case leyakCue
    case gameOver
}

/// The two loops the game switches between: the menu and the scored run.
enum BackgroundTrack: String {
    case menu = "homescreen-bgm"
    case gameplay = "gameplay-ginanti-bgm"
}

/// Audio seam for the whole app.
protocol AudioServicing: AnyObject {
    func setMusicVolume(_ volume: Double)
    func setSFXVolume(_ volume: Double)
    func play(_ effect: SoundEffect)
    func startBackgroundMusic(_ track: BackgroundTrack)
    func stopBackgroundMusic()
}

/// Placeholder implementation that only remembers the levels. Swap for an
/// `AVAudioPlayer`-backed service once the gamelan loop and effect files exist.
final class SilentAudioService: AudioServicing {
    private(set) var musicVolume: Double = GameSettings.default.musicVolume
    private(set) var sfxVolume: Double = GameSettings.default.sfxVolume

    func setMusicVolume(_ volume: Double) { musicVolume = volume }
    func setSFXVolume(_ volume: Double) { sfxVolume = volume }
    func play(_ effect: SoundEffect) {}
    func startBackgroundMusic(_ track: BackgroundTrack) {}
    func stopBackgroundMusic() {}
}

/// Plays the bundled BGM loops and one-shot SFX from `Resources/Audio`.
/// One shared player loops the current BGM track; SFX get a fresh player
/// each time so overlapping cues (a squat hit right after a coin, say) don't
/// cut each other off, kept alive in `activeEffects` until playback ends.
final class NariAudioService: NSObject, AudioServicing {
    /// Maps a cue to the file that plays for it. Cues left out here have no
    /// asset yet and stay silent — safe by design, not a bug.
    private static let effectFilenames: [SoundEffect: String] = [
        .buttonTap: "click-sfx",
        .calibrationComplete: "success-tring",
        .coinSpawned: "frangipani-appear",
        .coinCollected: "sparkle-sfx",
        .squatCue: "squat-cue-appears",
        .squatHit: "squat-mix",
        .squatHeld: "squat-completed-leak",
        .freezeCue: "agem-cue-triggers",
        .freezeLocked: "success-slowed",
        .freezeHeld: "success-tring",
        .leyakCue: "leak-appear",
    ]

    private var musicVolume: Double = GameSettings.default.musicVolume
    private var sfxVolume: Double = GameSettings.default.sfxVolume

    private var bgmPlayer: AVAudioPlayer?
    private var currentTrack: BackgroundTrack?
    private var activeEffects: Set<AVAudioPlayer> = []

    override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func setMusicVolume(_ volume: Double) {
        musicVolume = volume
        bgmPlayer?.volume = Float(volume)
    }

    func setSFXVolume(_ volume: Double) {
        sfxVolume = volume
    }

    func play(_ effect: SoundEffect) {
        guard let filename = Self.effectFilenames[effect],
              let url = Self.resourceURL(named: filename),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }

        player.volume = Float(sfxVolume)
        player.delegate = self
        activeEffects.insert(player)
        player.play()
    }

    func startBackgroundMusic(_ track: BackgroundTrack) {
        guard currentTrack != track else { return }
        currentTrack = track

        guard let url = Self.resourceURL(named: track.rawValue) else { return }
        bgmPlayer = try? AVAudioPlayer(contentsOf: url)
        bgmPlayer?.numberOfLoops = -1
        bgmPlayer?.volume = Float(musicVolume)
        bgmPlayer?.play()
    }

    func stopBackgroundMusic() {
        bgmPlayer?.stop()
        bgmPlayer = nil
        currentTrack = nil
    }

    /// SFX are `.wav`, BGM is `.mp3` — try both rather than hard-coding which
    /// is which per file.
    private static func resourceURL(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3")
    }
}

extension NariAudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activeEffects.remove(player)
    }
}
