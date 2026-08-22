import CoreGraphics
import Foundation

/// One coin waiting to be swept up during the walk.
struct Coin: Identifiable, Sendable {
    let id: UUID
    /// 1 up to `RunRules.coinTierCount`. A higher tier sits further out from
    /// the body, is drawn bigger, and pays more.
    let tier: Int
    /// Body space: the hip centre is the origin and one unit is a torso length.
    /// Placing coins here rather than on the screen is what makes them land in
    /// the same place relative to the player whether they are tall or small,
    /// close to the iPad or far from it.
    let position: CGPoint
    /// Radius in torso lengths, so it scales with the player like the position.
    let radius: CGFloat
    let value: Int
    let lifetime: Double
    var remaining: Double

    /// 1 when the coin has just appeared, 0 as it runs out.
    var remainingFraction: Double { max(0, min(1, remaining / lifetime)) }
}

/// Scatters coins around the player while they walk, ages them out, and reports
/// the ones a hand reached in time.
///
/// Everything here is in body space and knows nothing about the screen; the
/// view maps a coin onto the camera picture the same way it maps a pose marker.
struct CoinField {
    private(set) var coins: [Coin] = []
    private var timeToNextSpawn: Double = 0

    /// Advances by one frame and returns the value of every coin collected.
    mutating func advance(
        delta: Double,
        hands: [CGPoint],
        rules: RunRules,
        generator: inout SeededGenerator
    ) -> [Int] {
        var collected: [Int] = []

        // Collected before ageing, so a coin on its very last frame can still
        // be caught rather than vanishing out from under a hand.
        coins.removeAll { coin in
            let touched = hands.contains { hand in
                hypot(hand.x - coin.position.x, hand.y - coin.position.y) <= coin.radius
            }
            guard touched else { return false }
            collected.append(coin.value)
            return true
        }

        for index in coins.indices {
            coins[index].remaining -= delta
        }
        coins.removeAll { $0.remaining <= 0 }

        timeToNextSpawn -= delta
        if timeToNextSpawn <= 0 {
            timeToNextSpawn = Double.random(in: rules.coinSpawnInterval, using: &generator)
            if coins.count < rules.maximumCoinsOnScreen,
               let coin = spawn(rules: rules, generator: &generator) {
                coins.append(coin)
            }
        }

        return collected
    }

    /// Coins belong to the walk. An interrupt takes them off the floor so the
    /// player is not being asked to reach for something during a Freeze.
    mutating func clear() {
        coins.removeAll()
        timeToNextSpawn = 0
    }

    private func spawn(rules: RunRules, generator: inout SeededGenerator) -> Coin? {
        let tier = Int.random(in: 1...rules.coinTierCount, using: &generator)
        let step = rules.coinTierCount > 1
            ? CGFloat(tier - 1) / CGFloat(rules.coinTierCount - 1)
            : 0
        let distance = Self.lerp(rules.coinDistanceRange, step)
        let radius = Self.lerp(rules.coinRadiusRange, step)

        // A few attempts at a spot that is not already occupied. Giving up and
        // spawning nothing is fine — the next spawn comes along in a second.
        for _ in 0..<12 {
            // The upper half only: a coin below the hips cannot be reached
            // without dropping out of the walk, and a squat is a different cue.
            let angle = CGFloat.random(in: 0.08...0.92, using: &generator) * .pi
            let position = CGPoint(x: cos(angle) * distance, y: -sin(angle) * distance)

            let isClear = coins.allSatisfy { other in
                let gap = hypot(other.position.x - position.x, other.position.y - position.y)
                return gap >= other.radius + radius + rules.coinMinimumSeparation
            }
            guard isClear else { continue }

            return Coin(
                id: UUID(),
                tier: tier,
                position: position,
                radius: radius,
                value: tier * rules.coinValueStep,
                lifetime: rules.coinLifetime,
                remaining: rules.coinLifetime
            )
        }
        return nil
    }

    private static func lerp(_ range: ClosedRange<CGFloat>, _ step: CGFloat) -> CGFloat {
        range.lowerBound + (range.upperBound - range.lowerBound) * step
    }
}
