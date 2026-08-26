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
    case creditsAboutTitle
    case creditsAboutBody
    case creditsHowToPlayTitle
    case creditsHowToPlayStep1
    case creditsHowToPlayStep2
    case creditsHowToPlayStep3
    case creditsHowToPlayStep4
    case creditsHowToPlayStep5
    case creditsCreditsTitle
    case creditsCreditsBody

    // Gameplay
    case gameplayPlayTitle
    case gameplayPlaceholderBody
    case gameplayBack

    // Tutorial
    case tutorialTitle
    case tutorialSetup
    case tutorialStart
    case tutorialPreparing

    // Camera framing
    case cameraFieldWide
    case cameraFieldStandard
    case cameraFieldHint

    // Calibration
    case calibrationTitle
    case calibrationInstruction
    case calibrationSearching

    // Green room
    case startingTitle
    case greenRoomTrack
    case greenRoomArtist

    // Cues
    case cueWalk
    case cueSquat
    case cueFreeze
    case cueHold
    case cueNgayog
    case cueNgeed
    case cueLeyak
    case cueCollectHint

    // Event flashes
    case flashNice
    case flashMissed
    case flashLocked
    case flashPerfect
    case flashBroke
    case flashTooSlow
    case flashDodged
    case flashCaught

    // Game over
    case gameOverTitle
    case gameOverRetry
    case gameOverSurvived
    case gameOverBest
    case gameOverYourScore
    case gameOverNewHighScore
    case gameOverBestScoreLabel
    case gameOverShare
    case gameOverShareMessage
    case gameOverDownload
    case gameOverDownloadSaved
    case gameOverDownloadDenied

    // Score history
    case scoresTitle
    case scoresEmpty
    case scoresSignInRequired
    case scoresNotConfigured
    case scoresLoadFailed
    case scoresRetry
    case scoresYou

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
