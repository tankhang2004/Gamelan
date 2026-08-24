import CoreGraphics
import Foundation

/// One frangipani, ready to draw: where it sits on the camera picture, how big
/// it still is, and what it is still worth.
///
/// The radius and value here are the *wilted* ones — already scaled down for
/// however long the flower has been out — so the view draws exactly what the
/// hit test is measuring against.
struct CoinPlacement: Identifiable, Equatable, Sendable {
    let id: UUID
    /// Points it would pay if picked right now.
    let value: Int
    /// Normalized image coordinates, the same space a pose marker uses.
    let center: CGPoint
    /// Current radius in normalized image width.
    let radius: CGFloat
    /// 1 when it lands, 0 as it runs out.
    let remainingFraction: Double
}
