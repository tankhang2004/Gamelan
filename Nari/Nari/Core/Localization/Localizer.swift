import Foundation

/// Resolves a `LocalizedKey` for one language.
///
/// The tables live in Swift rather than in `.lproj` bundles on purpose: the game
/// lets the player switch language from the settings popup, and a plain
/// dictionary lookup re-renders SwiftUI immediately, while bundle-based
/// localisation only picks up a new language on relaunch.
struct Localizer: Equatable, Sendable {
    let language: AppLanguage

    subscript(key: LocalizedKey) -> String {
        Self.table(for: language)[key] ?? Self.table(for: .english)[key] ?? key.rawValue
    }

    func callAsFunction(_ key: LocalizedKey) -> String { self[key] }

    private static func table(for language: AppLanguage) -> [LocalizedKey: String] {
        switch language {
        case .indonesian: indonesian
        case .english: english
        }
    }

    private static let indonesian: [LocalizedKey: String] = [
        .menuPlay: "MULAI",
        .menuSettings: "PENGATURAN",
        .menuCredits: "INFO",
        .menuScores: "SKOR",
        .tagline: "Latihan tubuh untuk penari Bali cilik",

        .startingTitle: "Permainan Segera Dimulai!",
        .greenRoomTrack: "Ginanti",
        .greenRoomArtist: "oleh Mekar Bhuana",

        .cueWalk: "NGAYOG",
        .cueSquat: "NGE'ED!",
        .cueFreeze: "DIAM!",
        .cueHold: "TAHAN",
        .cueNgayog: "Ngayog",
        .cueNgeed: "Nge'ed",

        .flashNice: "MANTAP!",
        .flashMissed: "LEWAT",
        .flashLocked: "DAPAT!",
        .flashPerfect: "SEMPURNA!",
        .flashBroke: "GOYAH",
        .flashTooSlow: "KELAMAAN",

        .gameOverTitle: "Selesai",
        .gameOverRetry: "MAIN LAGI",
        .gameOverSurvived: "Bertahan",
        .gameOverBest: "Rekor baru!",
        .gameOverYourScore: "Skormu",
        .gameOverNewHighScore: "Rekor Baru!",
        .gameOverBestScoreLabel: "Skor terbaik",
        .gameOverShare: "Bagikan",
        .gameOverShareMessage: "Skorku %d di Yuk, Nari!",
        .gameOverDownload: "Unduh",
        .gameOverDownloadSaved: "Tersimpan ke galeri!",
        .gameOverDownloadDenied: "Tidak bisa akses galeri foto",

        .scoresTitle: "Riwayat Skor",
        .scoresEmpty: "Belum ada permainan.\nMain dulu, yuk!",

        .settingsTitle: "Pengaturan",
        .settingsMusicVolume: "Volume Musik",
        .settingsSFXVolume: "Volume Efek Suara",
        .settingsLanguage: "Bahasa",
        .settingsDone: "Selesai",

        .creditsTitle: "Kredit",
        .creditsAboutTitle: "Tentang",
        .creditsAboutBody: """
        Yuk, Nari! adalah permainan olahraga yang terinspirasi dari tari Bali, \
        mengubah gerakan dasar tarian tradisional ini jadi momen seru yang \
        bikin berkeringat.
        """,
        .creditsCreditsTitle: "Kredit",
        .creditsCreditsBody: """
        Pengetahuan koreografi dan musik gamelan disediakan oleh Mekar Bhuana.

        Instagram: @mekarbhuana_centre
        Website: [balimusicanddance.com](https://balimusicanddance.com)
        """,
        .gameplayPlayTitle: "Mode Main",
        .gameplayPlaceholderBody: "Layar permainan masih kosong. Alur gerak akan dipasang di sini.",
        .gameplayBack: "Kembali ke Menu",

        .tutorialTitle: "Siapkan Ruangmu",
        .tutorialSetup: "Letakkan iPad di lantai tegak, tekan SIAP, dan mundur.",
        .tutorialStart: "SIAP",

        .calibrationTitle: "KALIBRASI",
        .calibrationInstruction: "Kalibrasi...",
        .calibrationSearching: "Pastikan seluruh badanmu, dari kepala sampai kaki, masuk dalam frame",

        .playHoldInstruction: "Tahan pose sampai semua titik hijau",
        .playPause: "JEDA",
        .playResume: "LANJUT",
        .playExit: "Keluar",
        .playReps: "Berhasil",
        .playWellDone: "BAGUS!",
        .playBodyLost: "Badanmu keluar dari layar",

        .cameraDeniedTitle: "Kamera belum diizinkan",
        .cameraDeniedBody: "Buka Pengaturan dan izinkan Yuk, Nari! memakai kamera, lalu coba lagi.",
        .cameraMissingTitle: "Kamera tidak tersedia",
        .cameraMissingBody: "Perangkat ini tidak punya kamera yang bisa dipakai. Jalankan permainan di iPad asli.",
        .cameraOpenSettings: "Buka Pengaturan",

        .close: "Tutup",
    ]

    private static let english: [LocalizedKey: String] = [
        .menuPlay: "START",
        .menuSettings: "SETTINGS",
        .menuCredits: "INFO",
        .menuScores: "SCORES",
        .tagline: "Body training for young Balinese dancers",

        .startingTitle: "Game is Starting!",
        .greenRoomTrack: "Ginanti",
        .greenRoomArtist: "by Mekar Bhuana",

        .cueWalk: "WALK",
        .cueSquat: "SQUAT!",
        .cueFreeze: "FREEZE!",
        .cueHold: "HOLD",
        .cueNgayog: "Ngayog",
        .cueNgeed: "Nge'ed",

        .flashNice: "NICE!",
        .flashMissed: "MISSED",
        .flashLocked: "LOCKED!",
        .flashPerfect: "PERFECT!",
        .flashBroke: "WOBBLE",
        .flashTooSlow: "TOO SLOW",

        .gameOverTitle: "Game Over",
        .gameOverRetry: "PLAY AGAIN",
        .gameOverSurvived: "Survived",
        .gameOverBest: "New best!",
        .gameOverYourScore: "Your Score",
        .gameOverNewHighScore: "New High Score!",
        .gameOverBestScoreLabel: "Best score",
        .gameOverShare: "Share",
        .gameOverShareMessage: "I scored %d in Yuk, Nari!",
        .gameOverDownload: "Download",
        .gameOverDownloadSaved: "Saved to your photos!",
        .gameOverDownloadDenied: "Couldn't access your photo library",

        .scoresTitle: "Score History",
        .scoresEmpty: "No runs yet.\nGo dance one!",

        .settingsTitle: "Settings",
        .settingsMusicVolume: "Music Volume",
        .settingsSFXVolume: "Sound Effect Volume",
        .settingsLanguage: "Language",
        .settingsDone: "Done",

        .creditsTitle: "Credits",
        .creditsAboutTitle: "About",
        .creditsAboutBody: """
        Yuk, Nari! is an exercise game inspired by Balinese dance, channeling \
        the traditional art form's most basic movements into fun, \
        sweat-breaking moments.
        """,
        .creditsCreditsTitle: "Credits",
        .creditsCreditsBody: """
        Choreography knowledge and gamelan music provided by Mekar Bhuana.

        Instagram: @mekarbhuana_centre
        Website: [balimusicanddance.com](https://balimusicanddance.com)
        """,
        .gameplayPlayTitle: "Play Mode",
        .gameplayPlaceholderBody: "The gameplay screen is still empty. Movement flow goes here.",
        .gameplayBack: "Back to Menu",

        .tutorialTitle: "Set Up Your Space",
        .tutorialSetup: "Set your iPad upright on the floor, press READY, and step back",
        .tutorialStart: "READY",

        .calibrationTitle: "CALIBRATION",
        .calibrationInstruction: "Calibrating...",
        .calibrationSearching: "Make sure that you're fully in frame from head to toe",

        .playHoldInstruction: "Hold the pose until every dot turns green",
        .playPause: "PAUSE",
        .playResume: "RESUME",
        .playExit: "Exit",
        .playReps: "Completed",
        .playWellDone: "GREAT!",
        .playBodyLost: "You stepped out of frame",

        .cameraDeniedTitle: "Camera access is off",
        .cameraDeniedBody: "Open Settings and let Yuk, Nari! use the camera, then try again.",
        .cameraMissingTitle: "No camera available",
        .cameraMissingBody: "This device has no usable camera. Run the game on a real iPad.",
        .cameraOpenSettings: "Open Settings",

        .close: "Close",
    ]
}
