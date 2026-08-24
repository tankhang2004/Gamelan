import CoreGraphics
import Foundation

/// A burst struck where a foot landed, burning down over a fraction of a second.
struct FootSpark: Identifiable, Equatable, Sendable {
    let id = UUID()
    /// Normalized image space, the same coordinates a coin uses.
    let position: CGPoint
    let lifetime: Double
    /// Fixes this spark's own shape — how many spokes, which way they point,
    /// how far they throw. Drawn from once so the burst varies between steps
    /// but holds still within one, rather than reshuffling every frame.
    let seed: UInt64
    var age: Double = 0

    /// 0 the instant it lands, 1 as it goes out.
    var progress: Double { max(0, min(1, age / lifetime)) }
}
