import CoreGraphics
import Foundation

/// One frangipani waiting to be swept up during the walk.
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

    /// 1 when the flower has just appeared, 0 as it runs out.
    var remainingFraction: Double { max(0, min(1, remaining / lifetime)) }

    /// The flower wilts as it ages: it is drawn smaller and pays less the
    /// longer it goes unpicked. Both fall off together on purpose — the size
    /// on screen *is* the reward readout, so a player never has to read a
    /// number to know that the big one across the room is the one to chase.
    func currentRadius(_ rules: RunRules) -> CGFloat {
        radius * Self.lerp(rules.coinWiltScale, CGFloat(remainingFraction))
    }

    func currentValue(_ rules: RunRules) -> Int {
        let scale = Self.lerp(rules.coinWiltValue, CGFloat(remainingFraction))
        return max(1, Int((Double(value) * Double(scale)).rounded()))
    }

    private static func lerp(_ range: ClosedRange<CGFloat>, _ step: CGFloat) -> CGFloat {
        range.lowerBound + (range.upperBound - range.lowerBound) * step
    }
}

/// What one frame of the field did, so the loop can score the pickups and
/// sound the arrivals without `CoinField` knowing what a `RunEvent` is.
struct CoinFieldTick {
    var collected: [Int] = []
    var didSpawn = false
}

/// Scatters frangipanis across the room while the player marches, wilts them
/// as they age, and reports the ones a hand or a foot reached in time.
struct CoinField {
    private(set) var coins: [Coin] = []
    private var timeToNextSpawn: Double = 0

    /// Advances by one frame and reports what was picked and what arrived.
    ///
    /// `catchers` are the wrists and ankles — a flower is caught with whatever
    /// reaches it first. They and `player` are in normalized image space;
    /// `frameAspect` is the frame's height over its width, which turns a
    /// vertical gap into the same units as a horizontal one so a "distance"
    /// means the same in both.
    mutating func advance(
        delta: Double,
        catchers: [CGPoint],
        player: CGPoint?,
        frameAspect: CGFloat,
        rules: RunRules,
        generator: inout SeededGenerator
    ) -> CoinFieldTick {
        var tick = CoinFieldTick()

        // Collected before ageing, so a flower on its very last frame can
        // still be caught rather than vanishing out from under a hand. The
        // hit test uses the wilted radius, so a flower is exactly as hard to
        // catch as it looks.
        coins.removeAll { coin in
            let reach = coin.currentRadius(rules)
            let touched = catchers.contains { catcher in
                Self.distance(catcher, coin.position, frameAspect) <= reach
            }
            guard touched else { return false }
            tick.collected.append(coin.currentValue(rules))
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
                tick.didSpawn = true
            }
        }

        return tick
    }

    /// Flowers belong to the march. An interrupt takes them off the floor so
    /// the player is not being asked to reach for something during a Freeze.
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
