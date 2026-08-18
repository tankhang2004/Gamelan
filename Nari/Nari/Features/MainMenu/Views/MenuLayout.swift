import CoreGraphics

/// Sizes for the menu stage, derived from the actual stage size rather than
/// hard-coded, so the same layout holds on every iPad and while the window is
/// letterboxed (which is what happens when the device is held portrait and the
/// game keeps its landscape-only orientation).
struct MenuLayout {
    let horizontalPadding: CGFloat
    let columnWidth: CGFloat
    let primaryButtonHeight: CGFloat
    let secondaryButtonHeight: CGFloat
    let buttonSpacing: CGFloat
    let titleWidth: CGFloat
    let dancerHeight: CGFloat
    let valanceHeight: CGFloat
    /// Multiplier for type sizes, 1.0 on an 11-inch iPad in landscape.
    let typeScale: CGFloat

    init(size: CGSize) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)

        horizontalPadding = (width * 0.04).clamped(to: 28...64)
        columnWidth = (width * 0.27).clamped(to: 260...400)
        primaryButtonHeight = (height * 0.165).clamped(to: 88...152)
        secondaryButtonHeight = (height * 0.095).clamped(to: 58...94)
        buttonSpacing = (height * 0.022).clamped(to: 10...24)
        titleWidth = (width * 0.30).clamped(to: 220...420)
        dancerHeight = (height * 0.68).clamped(to: 320...620)
        valanceHeight = (height * 0.15).clamped(to: 86...150)
        typeScale = (height / Theme.Metrics.referenceStageHeight).clamped(to: 0.72...1.25)
    }

    func scaled(_ value: CGFloat) -> CGFloat { value * typeScale }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
