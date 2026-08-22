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

        .scoresTitle: "Riwayat Skor",
        .scoresEmpty: "Belum ada permainan.\nMain dulu, yuk!",

        .settingsTitle: "Pengaturan",
        .settingsMusicVolume: "Volume Musik",
        .settingsSFXVolume: "Volume Efek Suara",
        .settingsLanguage: "Bahasa",
        .settingsDone: "Selesai",

        .creditsTitle: "Kredit",
        .creditsInspirationTitle: "Inspirasi",
        .creditsInspirationBody: """
        Permainan ini lahir dari latihan tari Bali: agem sebagai sikap dasar, \
        mendak yang menuntut kaki kuat dan seimbang, serta ngegol yang melatih \
        kesadaran pinggul dan tubuh bagian tengah. Kami ingin latihan penunjang \
        itu terasa menyenangkan, bukan menjadi beban tambahan bagi penari muda.
        """,
        .creditsTeamTitle: "Tim Pengembang",
        .creditsMentorsTitle: "Pembimbing & Narasumber",
        .creditsThanksTitle: "Terima Kasih",
        .creditsThanksBody: """
        Terima kasih kepada para guru tari, sanggar, orang tua, dan penari muda \
        yang bersedia mencoba, memberi masukan, dan menjaga tradisi ini tetap \
        hidup. Permainan ini dibuat untuk melengkapi latihan di sanggar, bukan \
        menggantikannya.
        """,
        .creditsClose: "Tutup",
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

        .scoresTitle: "Score History",
        .scoresEmpty: "No runs yet.\nGo dance one!",

        .settingsTitle: "Settings",
        .settingsMusicVolume: "Music Volume",
        .settingsSFXVolume: "Sound Effect Volume",
        .settingsLanguage: "Language",
        .settingsDone: "Done",

        .creditsTitle: "Credits",
        .creditsInspirationTitle: "Inspiration",
        .creditsInspirationBody: """
        This game grew out of Balinese dance practice: agem as the base stance, \
        mendak with its demand for strong balanced legs, and ngegol which trains \
        hip and core awareness. We wanted the supporting exercises to feel like \
        play rather than one more chore for young dancers.
        """,
        .creditsTeamTitle: "Development Team",
        .creditsMentorsTitle: "Mentors & Advisors",
        .creditsThanksTitle: "Thank You",
        .creditsThanksBody: """
        Thank you to the dance teachers, sanggar, parents, and young dancers who \
        tried this out, gave feedback, and keep the tradition alive. The game is \
        meant to complement practice at the sanggar, never to replace it.
        """,
        .creditsClose: "Close",
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
