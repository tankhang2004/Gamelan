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

        .greenRoomTrack: "Gamelan — Tabuh Pertama",
        .greenRoomStart: "SIAP!",

        .cueWalk: "NGAYOG",
        .cueSquat: "NGE'ED!",
        .cueFreeze: "DIAM!",
        .cueHold: "TAHAN",
        .cueNgayog: "Ngayog",

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
        .gameOverDownload: "Unduh",

        .scoresTitle: "Riwayat Skor",
        .scoresEmpty: "Belum ada permainan.\nMain dulu, yuk!",

        .settingsTitle: "Pengaturan",
        .settingsMusicVolume: "Volume Musik",
        .settingsSFXVolume: "Volume Efek Suara",
        .settingsLanguage: "Bahasa",
        .settingsDone: "Selesai",

        .creditsTitle: "Kredit",
        .creditsThanksTitle: "Terima Kasih",
        .creditsThanksBody: """
        Permainan ini terinspirasi oleh Mekar Bhuana Centre, pusat seni dan \
        budaya Bali yang telah membagikan ilmu dan semangatnya dalam \
        melestarikan tari Bali. Kunjungi mereka di [mekarbhuana.com](https://mekarbhuana.com).
        """,
        .gameplayPlayTitle: "Mode Main",
        .gameplayPlaceholderBody: "Layar permainan masih kosong. Alur gerak akan dipasang di sini.",
        .gameplayBack: "Kembali ke Menu",

        .tutorialTitle: "Siapkan Ruangmu",
        .tutorialSetup: "Letakkan iPad di lantai tegak, tekan SIAP, dan mundur.",
        .tutorialStart: "SIAP",

        .calibrationTitle: "KALIBRASI",
        .calibrationInstruction: "Berdiri tegak, biarkan seluruh badan terlihat",
        .calibrationSearching: "Mencari badanmu...",
        .calibrationDone: "Siap!",

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

        .greenRoomTrack: "Gamelan — First Tabuh",
        .greenRoomStart: "GAME START",

        .cueWalk: "WALK",
        .cueSquat: "SQUAT!",
        .cueFreeze: "FREEZE!",
        .cueHold: "HOLD",
        .cueNgayog: "Ngayog",

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
        .gameOverDownload: "Download",

        .scoresTitle: "Score History",
        .scoresEmpty: "No runs yet.\nGo dance one!",

        .settingsTitle: "Settings",
        .settingsMusicVolume: "Music Volume",
        .settingsSFXVolume: "Sound Effect Volume",
        .settingsLanguage: "Language",
        .settingsDone: "Done",

        .creditsTitle: "Credits",
        .creditsThanksTitle: "Thank You",
        .creditsThanksBody: """
        This game was inspired by Mekar Bhuana Centre, a Balinese arts and \
        culture center that generously shared its knowledge and passion for \
        preserving Balinese dance. Visit them at [mekarbhuana.com](https://mekarbhuana.com).
        """,
        .gameplayPlayTitle: "Play Mode",
        .gameplayPlaceholderBody: "The gameplay screen is still empty. Movement flow goes here.",
        .gameplayBack: "Back to Menu",

        .tutorialTitle: "Set Up Your Space",
        .tutorialSetup: "Set your iPad upright on the floor, press READY, and step back",
        .tutorialStart: "READY",

        .calibrationTitle: "CALIBRATION",
        .calibrationInstruction: "Stand tall and let your whole body show",
        .calibrationSearching: "Looking for you...",
        .calibrationDone: "Ready!",

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
