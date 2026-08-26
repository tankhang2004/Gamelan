import SwiftUI

/// Colours, type styles, and timings shared by every screen.
///
/// The values come from the Hi-Fi section of the Figma file: thick paint on
/// paper, periwinkle and ink over a yellow ground. Nothing here is a flat
/// system colour on purpose — every surface is meant to read as painted.
enum Theme {

    // MARK: - Palette

    enum Palette {
        /// The periwinkle every button, meter, and title is painted in.
        static let indigo = Color(hex: 0x5B62B0)
        static let indigoDeep = Color(hex: 0x3F4589)
        static let indigoLight = Color(hex: 0x8C92CE)

        /// Outline colour. Every painted shape is drawn round in this.
        static let ink = Color(hex: 0x0F1923)

        /// The yellow ground the menu and cue cards sit on.
        static let ochre = Color(hex: 0xE8CE2A)
        static let ochreDeep = Color(hex: 0xC9A81E)
        static let ochreLight = Color(hex: 0xF4E45C)

        /// Torn paper the pose cards and meters are printed on.
        static let paper = Color(hex: 0xEFE7D6)
        static let paperShade = Color(hex: 0xD8CDB6)

        /// Cream lettering, used on top of indigo and ink.
        static let cream = Color(hex: 0xE5ECE4)

        /// Pose feedback: a body point in the right place, and one that is not.
        static let poseCorrect = Color(hex: 0x2FA090)
        static let poseWrong = Color(hex: 0xE2564E)

        /// The orange frame that flashes round the screen on a Freeze cue.
        static let cueOrange = Color(hex: 0xF08A3C)
        /// The pink brushstroke Game Over is written across.
        static let gameOverPink = Color(hex: 0xFA3D68)

        /// Taksu meter fill, low to full.
        static let taksuLow = Color(hex: 0xE2564E)
        static let taksuMid = Color(hex: 0xE8CE2A)
        static let taksuFull = Color(hex: 0x5B62B0)

        static let pencil = Color(hex: 0x2A2622)
        static let scrim = Color(hex: 0x0F1923).opacity(0.62)
    }

    // MARK: - Layout

    enum Metrics {
        /// Height of an 11-inch iPad in landscape, the size every screen is
        /// tuned for. `MenuLayout` scales everything else against it.
        static let referenceStageHeight: CGFloat = 834
        static let screenPadding: CGFloat = 48
        static let popupCornerRadius: CGFloat = 28
        static let popupMaxWidth: CGFloat = 860
        static let popupMaxHeight: CGFloat = 700
        /// Width of the ink outline drawn round painted shapes, at reference size.
        static let inkStroke: CGFloat = 5
    }

    // MARK: - Motion

    enum Motion {
        static let contentFade = Animation.easeOut(duration: 0.45)
        static let popup = Animation.spring(response: 0.38, dampingFraction: 0.82)

        /// A cue card slamming onto the screen. The overshoot is what sells the
        /// weight of a painted board being dropped into frame.
        static let cueDrop = Animation.spring(response: 0.34, dampingFraction: 0.58)
        /// Taksu changes are eased rather than snapped so the player can see
        /// which direction the meter moved.
        static let meter = Animation.easeOut(duration: 0.35)
        static let screenChange = Animation.easeInOut(duration: 0.32)
    }

    // MARK: - Type

    /// Display type is Henny Penny and button type is Instrument Serif, matching
    /// the Figma. Neither ships with iOS, so each style falls back to the nearest
    /// system design when the font file is not in the bundle — see the README for
    /// how to drop the real files in.
    enum Fonts {
        private static let display = "HennyPenny-Regular"
        private static let serif = "InstrumentSerif-Regular"

        static func title(_ size: CGFloat) -> Font {
            custom(display, size: size) ?? .system(size: size, weight: .heavy, design: .serif)
        }

        static func label(_ size: CGFloat) -> Font {
            custom(serif, size: size) ?? .system(size: size, weight: .semibold, design: .serif)
        }

        static func body(_ size: CGFloat) -> Font {
            custom(serif, size: size) ?? .system(size: size, weight: .regular, design: .serif)
        }

        /// Numbers on the HUD. Monospaced digits so a rising score does not make
        /// the swatch under it jitter.
        static func readout(_ size: CGFloat) -> Font {
            .system(size: size, weight: .bold, design: .serif).monospacedDigit()
        }

        private static func custom(_ name: String, size: CGFloat) -> Font? {
            guard UIFont(name: name, size: size) != nil else { return nil }
            return .custom(name, size: size)
        }
    }
}

extension Color {
    /// Builds a colour from a 24-bit RGB literal such as `0x5B62B0`.
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

extension View {
    /// The house style for words printed over the live camera.
    ///
    /// Everything on the stage is fighting a moving photograph for contrast,
    /// and a hard outline was losing: it thickened the letterforms until they
    /// read as a sticker and still disappeared over a bright wall. A soft drop
    /// shadow plus a dimmed block behind the line does the same job by putting
    /// a known background under the text rather than by armouring the text
    /// itself.
    func stageCaption(
        size: CGFloat,
        color: Color = .white,
        blockOpacity: Double = 0.42
    ) -> some View {
        self
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .shadow(color: Theme.Palette.ink.opacity(0.75), radius: size * 0.10, y: size * 0.05)
            .padding(.horizontal, size * 0.5)
            .padding(.vertical, size * 0.22)
            .background(
                RoundedRectangle(cornerRadius: size * 0.35, style: .continuous)
                    .fill(Theme.Palette.ink.opacity(blockOpacity))
            )
    }
}
