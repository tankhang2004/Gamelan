import Foundation

/// Every user-facing string in the app, referenced by case rather than by raw
/// string so a missing translation is a compile error instead of a blank label.
enum LocalizedKey: String, CaseIterable, Sendable {
    // Main menu
    case menuPlay
    case menuSettings
    case menuCredits
    case menuScores
    case tagline

    // Settings popup
    case settingsTitle
    case settingsMusicVolume
    case settingsSFXVolume
    case settingsLanguage
    case settingsDone

    // Credits popup
    case creditsTitle
    case creditsInspirationTitle
    case creditsInspirationBody
    case creditsTeamTitle
    case creditsMentorsTitle
    case creditsThanksTitle
    case creditsThanksBody
    case creditsClose

    // Gameplay
    case gameplayPlayTitle
    case gameplayPlaceholderBody
    case gameplayBack

    // Tutorial
    case tutorialTitle
    case tutorialStep1
    case tutorialStep2
    case tutorialStep3
    case tutorialStart

    // Calibration
    case calibrationTitle
    case calibrationInstruction
    case calibrationSearching
    case calibrationDone

    // Green room
    case greenRoomTrack
    case greenRoomStart

    // Cues
    case cueWalk
    case cueSquat
    case cueFreeze
    case cueHold
    case cueNgayog

    // Event flashes
    case flashNice
    case flashMissed
    case flashLocked
    case flashPerfect
    case flashBroke
    case flashTooSlow

    // Game over
    case gameOverTitle
    case gameOverRetry
    case gameOverSurvived
    case gameOverBest

    // Score history
    case scoresTitle
    case scoresEmpty

    // Play
    case playHoldInstruction
    case playPause
    case playResume
    case playExit
    case playReps
    case playWellDone
    case playBodyLost

    // Camera problems
    case cameraDeniedTitle
    case cameraDeniedBody
    case cameraMissingTitle
    case cameraMissingBody
    case cameraOpenSettings

    // Generic
    case close
}
