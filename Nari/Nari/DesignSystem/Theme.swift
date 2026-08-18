import SwiftUI

/// Colours, type styles, and timings shared by every screen. Keeping them in one
/// place means the look can be retuned once the real art direction lands.
enum Theme {

    // MARK: - Palette

    enum Palette {
        /// The three cloth colours of a Balinese ceremonial curtain.
        static let curtainRed = Color(hex: 0xB0272E)
        static let curtainRedDeep = Color(hex: 0x7E1A20)
        static let curtainGold = Color(hex: 0xE9B63C)
        static let curtainGoldDeep = Color(hex: 0xC08C1E)
        static let curtainCream = Color(hex: 0xF4E7D0)

        /// Carved wood and gold leaf, used for plaques and frames.
        static let woodDark = Color(hex: 0x40230F)
        static let woodMid = Color(hex: 0x6B3B1B)
        static let goldTrim = Color(hex: 0xE2BE6A)
        static let goldTrimBright = Color(hex: 0xF7E2A8)

        /// Stage behind the curtains.
        static let stageDeep = Color(hex: 0x14100E)
        static let stageWarm = Color(hex: 0x2A1B14)

        /// Pose feedback: a body point in the right place, and one that is not.
        static let poseCorrect = Color(hex: 0x2FBF57)
        static let poseWrong = Color(hex: 0xE2564E)

        /// Sketchbook paper for the tutorial drawings.
        static let paper = Color(hex: 0xF7F2E6)
        static let pencil = Color(hex: 0x2A2622)

        static let ink = Color(hex: 0x2B1810)
        static let parchment = Color(hex: 0xFBF3E2)
        static let scrim = Color.black.opacity(0.55)
    }

    // MARK: - Layout

    enum Metrics {
        /// Height of an 11-inch iPad in landscape, the size the menu is tuned
        /// for. `MenuLayout` scales everything else against it.
        static let referenceStageHeight: CGFloat = 834
        static let screenPadding: CGFloat = 48
        static let popupCornerRadius: CGFloat = 28
        static let popupMaxWidth: CGFloat = 620
    }

    // MARK: - Motion

    enum Motion {
        /// Curtains swinging shut when the menu appears.
        static let curtainClose = Animation.timingCurve(0.25, 0.9, 0.3, 1.0, duration: 1.0)
        /// Curtains swinging aside after the player picks a mode. The spring
        /// overshoot is what makes the cloth read as heavy and swinging.
        static let curtainOpen = Animation.spring(response: 0.95, dampingFraction: 0.68)
        static let curtainOpenDuration: TimeInterval = 1.05
        static let curtainCloseDuration: TimeInterval = 1.0

        static let contentFade = Animation.easeOut(duration: 0.45)
        static let popup = Animation.spring(response: 0.38, dampingFraction: 0.82)
    }

    // MARK: - Type

    enum Fonts {
        static func title(_ size: CGFloat) -> Font {
            .system(size: size, weight: .heavy, design: .rounded)
        }

        static func label(_ size: CGFloat) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }

        static func body(_ size: CGFloat) -> Font {
            .system(size: size, weight: .regular, design: .rounded)
        }
    }
}

extension Color {
    /// Builds a colour from a 24-bit RGB literal such as `0xE9B63C`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
