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
    case squatCue
    case squatHit
    case squatMiss
    /// The gong that marks the music cutting out for a Freeze.
    case freezeCue
    /// The pose locked in and the hold began.
    case freezeLocked
    case freezeHeld
    case freezeBroken
    case freezeFailed
    case energyLow
    case gameOver
}

/// Audio seam for the whole app.
protocol AudioServicing: AnyObject {
    func setMusicVolume(_ volume: Double)
    func setSFXVolume(_ volume: Double)
    func play(_ effect: SoundEffect)
    func startBackgroundMusic()
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
    func startBackgroundMusic() {}
    func stopBackgroundMusic() {}
}
