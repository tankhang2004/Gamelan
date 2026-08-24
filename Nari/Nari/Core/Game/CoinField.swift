import CoreGraphics
import Foundation

/// One coin waiting to be swept up during the walk.
struct Coin: Identifiable, Sendable {
    let id: UUID
    /// 1 up to `RunRules.coinTierCount`. A coin that spawned further from the
    /// player is a higher tier: drawn bigger, worth more, and out longer.
    let tier: Int
    /// Normalized image space, the same coordinates a pose marker uses.
    ///
    /// Pinned to the picture rather than to the player on purpose. A coin held
    /// in body space travels with the hips, so walking towards one would push
    /// it away at exactly the speed you approached — the one thing a coin meant
    /// to be chased must not do.
    let position: CGPoint
    /// Radius as a fraction of the frame width.
    let radius: CGFloat
    let value: Int
    let lifetime: Double
    var remaining: Double

    /// 1 when the coin has just appeared, 0 as it runs out.
    var remainingFraction: Double { max(0, min(1, remaining / lifetime)) }
}

/// Scatters coins across the room while the player walks, ages them out, and
/// reports the ones a hand reached in time.
struct CoinField {
    private(set) var coins: [Coin] = []
    private var timeToNextSpawn: Double = 0

    /// Advances by one frame and returns the value of every coin collected.
    ///
    /// `hands` and `player` are in normalized image space; `frameAspect` is the
    /// frame's height over its width, which turns a vertical gap into the same
    /// units as a horizontal one so a "distance" means the same in both.
    mutating func advance(
        delta: Double,
        hands: [CGPoint],
        player: CGPoint?,
        frameAspect: CGFloat,
        rules: RunRules,
        generator: inout SeededGenerator
    ) -> [Int] {
        var collected: [Int] = []

        // Collected before ageing, so a coin on its very last frame can still
        // be caught rather than vanishing out from under a hand.
        coins.removeAll { coin in
            let touched = hands.contains { hand in
                Self.distance(hand, coin.position, frameAspect) <= coin.radius
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
               let player,
               let coin = spawn(near: player, frameAspect: frameAspect, rules: rules, generator: &generator) {
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

    private func spawn(
        near player: CGPoint,
        frameAspect: CGFloat,
        rules: RunRules,
        generator: inout SeededGenerator
    ) -> Coin? {
        let area = rules.coinPlayArea
        let reach = rules.coinPlayerDistanceRange

        // Points are drawn from the whole frame and rejected, rather than
        // placed at a chosen angle and distance. Sampling the frame is what
        // puts coins in the corners: aiming at a distance from the player would
        // trace a circle around them and mostly miss the corners entirely.
        for _ in 0..<24 {
            let position = CGPoint(
                x: CGFloat.random(in: area.minX...area.maxX, using: &generator),
                y: CGFloat.random(in: area.minY...area.maxY, using: &generator)
            )

            let gap = Self.distance(position, player, frameAspect)
            guard reach.contains(gap) else { continue }

            // How far out it landed decides everything else about it, so the
            // coins worth chasing are visibly the ones across the room.
            let step = (gap - reach.lowerBound) / (reach.upperBound - reach.lowerBound)
            let tier = max(1, min(rules.coinTierCount, Int(step * CGFloat(rules.coinTierCount)) + 1))
            let tierStep = rules.coinTierCount > 1
                ? CGFloat(tier - 1) / CGFloat(rules.coinTierCount - 1)
                : 0
            let radius = Self.lerp(rules.coinRadiusRange, tierStep)

            let isClear = coins.allSatisfy { other in
                Self.distance(other.position, position, frameAspect)
                    >= other.radius + radius + rules.coinMinimumSeparation
            }
            guard isClear else { continue }

            let lifetime = Double(Self.lerp(
                CGFloat(rules.coinLifetime.lowerBound)...CGFloat(rules.coinLifetime.upperBound),
                tierStep
            ))

            return Coin(
                id: UUID(),
                tier: tier,
                position: position,
                radius: radius,
                value: tier * rules.coinValueStep,
                lifetime: lifetime,
                remaining: lifetime
            )
        }
        return nil
    }

    /// Distance in frame widths. The vertical gap is scaled by the frame's
    /// shape first, so a coin "a third of the way away" is the same walk
    /// whichever direction it lies in.
    private static func distance(_ a: CGPoint, _ b: CGPoint, _ frameAspect: CGFloat) -> CGFloat {
        hypot(a.x - b.x, (a.y - b.y) * frameAspect)
    }

    private static func lerp(_ range: ClosedRange<CGFloat>, _ step: CGFloat) -> CGFloat {
        range.lowerBound + (range.upperBound - range.lowerBound) * step
    }
}
