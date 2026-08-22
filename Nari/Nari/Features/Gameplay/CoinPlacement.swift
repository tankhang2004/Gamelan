import CoreGraphics
import Foundation

/// One coin, ready to draw: where it sits on the camera picture and how much
/// of its four seconds is left.
struct CoinPlacement: Identifiable, Equatable, Sendable {
    let id: UUID
    let value: Int
    /// Normalized image coordinates, the same space a pose marker uses.
    let center: CGPoint
    /// Radius in normalized image width.
    let radius: CGFloat
    /// 1 when it lands, 0 as it runs out.
    let remainingFraction: Double
}
