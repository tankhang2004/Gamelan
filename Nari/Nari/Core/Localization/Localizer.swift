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
        .menuCredits: "INFORMASI",
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

        .scoresTitle: "Papan Peringkat",
        .scoresEmpty: "Belum ada skor di papan peringkat.\nJadilah yang pertama!",
        .scoresSignInRequired: "Masuk ke Game Center untuk melihat papan peringkat dunia.",
        .scoresYou: "Kamu",

        .settingsTitle: "Pengaturan",
        .settingsMusicVolume: "Volume Musik",
        .settingsSFXVolume: "Volume Efek Suara",
        .settingsLanguage: "Bahasa",
        .settingsDone: "Selesai",

        .creditsTitle: "Informasi",
        .creditsAboutTitle: "Tentang",
        .creditsAboutBody: """
        Yuk, Nari! adalah permainan olahraga yang terinspirasi dari tari Bali, \
        mengubah gerakan dasar tarian tradisional ini jadi momen seru yang \
        bikin berkeringat.
        """,
        .creditsHowToPlayTitle: "Cara Bermain",
        .creditsHowToPlayStep1: "1. NGAYOG, NGAYOG, NGAYOG! Tapi lakukan perlahan, seperti penari.",
        .creditsHowToPlayStep2: "2. Perhatikan sisi kanan layar untuk referensi!",
        .creditsHowToPlayStep3: "3. Kumpulkan BUNGA JEPUN saat berjalan untuk poin tambahan!",
        .creditsHowToPlayStep4: "4. Saat permainan memberi peringatan, NGE'ED dan tahan posisimu untuk menghindari Leyak yang terbang, tapi jangan. berhenti. berjalan!",
        .creditsHowToPlayStep5: "5. Bersiaplah melakukan pose AGEM kapan saja! Begitu kamu melakukannya, DIAM di tempat!",

        .creditsCreditsTitle: "Kredit",
        .creditsCreditsBody: """
        Pengetahuan akan koreografi tarian dan musik gamelan untuk \
        permainan ini terinspirasi oleh Mekar Bhuana Centre.

        Mekar Bhuana berarti "mekar ke seluruh dunia" — misi komunitas \
        ini adalah membuat musik dan tari kuno Bali dikenal kembali dan \
        dilestarikan, baik di Bali maupun di seluruh dunia.

        Instagram: @mekarbhuana_centre
        Website: [balimusicanddance.com](https://balimusicanddance.com)
        """,
        .gameplayPlayTitle: "Mode Main",
        .gameplayPlaceholderBody: "Layar permainan masih kosong. Alur gerak akan dipasang di sini.",
        .gameplayBack: "Kembali ke Menu",

        .tutorialTitle: "Siapkan Ruangmu",
        .tutorialSetup: "Letakkan iPad di lantai tegak, tekan SIAP, dan mundur.",
        .tutorialStart: "SIAP",

        .cameraFieldWide: "Lebar",
        .cameraFieldStandard: "Normal",
        .cameraFieldHint: "Tidak muat? Pakai Lebar.",

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

        .scoresTitle: "Leaderboard",
        .scoresEmpty: "No scores on the board yet.\nBe the first!",
        .scoresSignInRequired: "Sign in to Game Center to see the world leaderboard.",
        .scoresYou: "You",

        .settingsTitle: "Settings",
        .settingsMusicVolume: "Music Volume",
        .settingsSFXVolume: "Sound Effect Volume",
        .settingsLanguage: "Language",
        .settingsDone: "Done",

        .creditsTitle: "Information",
        .creditsAboutTitle: "About",
        .creditsAboutBody: """
        Yuk, Nari! is an exercise game inspired by Balinese dance, channeling \
        the traditional art form's most basic movements into fun, \
        sweat-breaking moments.
        """,
        .creditsHowToPlayTitle: "How to Play",
        .creditsHowToPlayStep1: "1. WALK, WALK, WALK! But do it gently, like a dancer.",
        .creditsHowToPlayStep2: "2. Pay attention to the right side of the screen for reference!",
        .creditsHowToPlayStep3: "3. Collect FRANGIPANIS as you walk for extra points!",
        .creditsHowToPlayStep4: "4. When the game tells you, SQUAT and hold the position to avoid the flying Leyak, but don't. stop. walking!",
        .creditsHowToPlayStep5: "5. Be ready to do the AGEM pose at any moment! Once you do, FREEZE!",

        .creditsCreditsTitle: "Credits",
        .creditsCreditsBody: """
        Knowledge of Balinese choreography and gamelan music for this \
        game was inspired by Mekar Bhuana Centre.

        Mekar Bhuana means "to blossom around the world" — the \
        community's mission is to help Bali's ancient music and dance \
        become known again and preserved, both on the island and abroad.

        Instagram: @mekarbhuana_centre
        Website: [balimusicanddance.com](https://balimusicanddance.com)
        """,
        .gameplayPlayTitle: "Play Mode",
        .gameplayPlaceholderBody: "The gameplay screen is still empty. Movement flow goes here.",
        .gameplayBack: "Back to Menu",

        .tutorialTitle: "Set Up Your Space",
        .tutorialSetup: "Set your iPad upright on the floor, press READY, and step back",
        .tutorialStart: "READY",

        .cameraFieldWide: "Wide",
        .cameraFieldStandard: "Normal",
        .cameraFieldHint: "Not fitting? Try Wide.",

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
