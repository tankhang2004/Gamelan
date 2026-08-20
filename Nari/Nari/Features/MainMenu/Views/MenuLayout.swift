import CoreGraphics

/// Sizes for the menu stage, derived from the actual stage size rather than
/// hard-coded, so the same layout holds on every iPad and while the window is
/// letterboxed (which is what happens when the device is held portrait and the
/// game keeps its landscape-only orientation).
struct MenuLayout {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let iconDiameter: CGFloat
    let iconSpacing: CGFloat
    let playButtonHeight: CGFloat
    let titleWidth: CGFloat
    let dancerHeight: CGFloat
    /// Multiplier for type sizes, 1.0 on an 11-inch iPad in landscape.
    let typeScale: CGFloat

    init(size: CGSize) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)

        horizontalPadding = (width * 0.045).clamped(to: 28...72)
        verticalPadding = (height * 0.035).clamped(to: 20...52)
        iconDiameter = (height * 0.078).clamped(to: 52...86)
        iconSpacing = (width * 0.014).clamped(to: 10...26)
        playButtonHeight = (height * 0.118).clamped(to: 68...118)
        titleWidth = (width * 0.38).clamped(to: 260...520)
        dancerHeight = (height * 0.92).clamped(to: 340...760)
        typeScale = (height / Theme.Metrics.referenceStageHeight).clamped(to: 0.72...1.25)
    }

    func scaled(_ value: CGFloat) -> CGFloat { value * typeScale }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
