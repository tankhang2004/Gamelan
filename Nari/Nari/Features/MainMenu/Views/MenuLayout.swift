import CoreGraphics

/// Sizes for the menu stage, derived from the actual stage size rather than
/// hard-coded, so the same layout holds on every iPad in either orientation.
///
/// Everything that used to be a fraction of `height` is a fraction of the
/// *shorter* edge instead. In landscape the two are the same thing, so nothing
/// there moves; in portrait the long edge is height, and scaling furniture off
/// it is what made the dancer swallow the screen.
struct MenuLayout {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let iconDiameter: CGFloat
    let iconSpacing: CGFloat
    let playButtonHeight: CGFloat
    let titleWidth: CGFloat
    let dancerHeight: CGFloat
    /// How far past `dancerHeight` the dancer blooms once the menu lands.
    /// Landscape deliberately overflows the stage — she is cropped by the
    /// bottom edge, which is the intended framing. Portrait has to stay
    /// inside it, or she covers the title and the start prompt both.
    let dancerBloom: CGFloat
    let dancerOffset: CGSize
    let isPortrait: Bool
    /// Multiplier for type sizes, 1.0 on an 11-inch iPad in landscape.
    let typeScale: CGFloat

    init(size: CGSize) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let shortSide = min(width, height)
        let portrait = height > width
        isPortrait = portrait

        horizontalPadding = (width * 0.045).clamped(to: 28...72)
        verticalPadding = (shortSide * 0.035).clamped(to: 20...52)
        iconDiameter = (shortSide * 0.078).clamped(to: 52...86)
        iconSpacing = (width * 0.014).clamped(to: 10...26)
        playButtonHeight = (shortSide * 0.118).clamped(to: 68...118)
        titleWidth = (width * 0.38).clamped(to: 260...520)
        typeScale = (shortSide / Theme.Metrics.referenceStageHeight).clamped(to: 0.72...1.25)

        if portrait {
            // Sized to the band left between the logo above her and the start
            // prompt below, and left at her own size rather than bloomed past
            // it — in portrait there is no bottom edge to crop her against
            // that isn't already spoken for.
            dancerHeight = (height * 0.55).clamped(to: 320...820)
            dancerBloom = 1
            dancerOffset = CGSize(width: 0, height: height * 0.03)
        } else {
            dancerHeight = (height * 0.92).clamped(to: 340...760)
            dancerBloom = 1.4
            dancerOffset = CGSize(width: 60, height: 30)
        }
    }

    func scaled(_ value: CGFloat) -> CGFloat { value * typeScale }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
