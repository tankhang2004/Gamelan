import SwiftUI

/// A repeatable pseudo-random source.
///
/// Every painted edge in the app is jittered, and the jitter has to be the same
/// on every redraw — a shape reseeded per frame would boil like bad animation.
/// Seeding from a caller-chosen number gives each shape its own fixed silhouette.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Any non-zero start works; the offset just keeps seed 0 from degenerating.
        state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func jitter(_ amount: CGFloat) -> CGFloat {
        CGFloat.random(in: -amount...amount, using: &self)
    }
}

/// A rectangle whose edges are torn rather than cut, for the paper the pose
/// cards and the Taksu meter are printed on.
struct TornEdgeShape: Shape {
    var seed: UInt64
    /// How far the edge wanders, as a fraction of the shorter side.
    var roughness: CGFloat = 0.035
    /// Points per edge. More points make a finer tear.
    var steps: Int = 9

    func path(in rect: CGRect) -> Path {
        var generator = SeededGenerator(seed: seed)
        let amount = min(rect.width, rect.height) * roughness

        var points: [CGPoint] = []
        points += edge(from: rect.origin, to: CGPoint(x: rect.maxX, y: rect.minY), axis: .vertical, amount: amount, using: &generator)
        points += edge(from: CGPoint(x: rect.maxX, y: rect.minY), to: CGPoint(x: rect.maxX, y: rect.maxY), axis: .horizontal, amount: amount, using: &generator)
        points += edge(from: CGPoint(x: rect.maxX, y: rect.maxY), to: CGPoint(x: rect.minX, y: rect.maxY), axis: .vertical, amount: amount, using: &generator)
        points += edge(from: CGPoint(x: rect.minX, y: rect.maxY), to: rect.origin, axis: .horizontal, amount: amount, using: &generator)

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private enum Axis { case horizontal, vertical }

    /// Walks one edge, nudging each intermediate point perpendicular to it.
    private func edge(
        from start: CGPoint,
        to end: CGPoint,
        axis: Axis,
        amount: CGFloat,
        using generator: inout SeededGenerator
    ) -> [CGPoint] {
        (0..<steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            let offset = generator.jitter(amount)
            return axis == .vertical
                ? CGPoint(x: x, y: y + offset)
                : CGPoint(x: x + offset, y: y)
        }
    }
}

/// One thick stroke of paint: a capsule with a loaded, uneven top and bottom.
/// Used for the score and timer swatches, and blown up for the Game Over mark.
struct BrushSwatchShape: Shape {
    var seed: UInt64
    var roughness: CGFloat = 0.16
    var steps: Int = 14

    func path(in rect: CGRect) -> Path {
        var generator = SeededGenerator(seed: seed)
        let amount = rect.height * roughness
        let inset = rect.height * 0.5

        var path = Path()
        let topStart = CGPoint(x: rect.minX + inset, y: rect.minY)
        path.move(to: topStart)

        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let x = rect.minX + inset + (rect.width - inset * 2) * t
            path.addLine(to: CGPoint(x: x, y: rect.minY + generator.jitter(amount)))
        }

        // Round the right end the way a brush lifts off.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: rect.maxY),
            control: CGPoint(x: rect.maxX + inset * 0.4, y: rect.midY)
        )

        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let x = rect.maxX - inset - (rect.width - inset * 2) * t
            path.addLine(to: CGPoint(x: x, y: rect.maxY + generator.jitter(amount)))
        }

        path.addQuadCurve(
            to: topStart,
            control: CGPoint(x: rect.minX - inset * 0.4, y: rect.midY)
        )
        path.closeSubpath()
        return path
    }
}

/// Horizontal brush marks laid over a colour, so a flat fill reads as painted
/// board rather than a rectangle. Drawn once into a `Canvas` — it is static, so
/// it costs nothing per frame.
struct PaintTexture: View {
    var seed: UInt64 = 7
    var base: Color = Theme.Palette.ochre
    var highlight: Color = Theme.Palette.ochreLight
    var shadow: Color = Theme.Palette.ochreDeep
    var strokeCount: Int = 46

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))

            var generator = SeededGenerator(seed: seed)

            // Broad tonal blocks first. Without them the strokes read as
            // wallpaper stripes; with them the surface has somewhere to catch
            // and lose the light, the way loaded paint does.
            for _ in 0..<7 {
                let rect = CGRect(
                    x: size.width * CGFloat.random(in: -0.2...0.7, using: &generator),
                    y: size.height * CGFloat.random(in: -0.2...0.8, using: &generator),
                    width: size.width * CGFloat.random(in: 0.35...0.9, using: &generator),
                    height: size.height * CGFloat.random(in: 0.2...0.6, using: &generator)
                )
                let tone = Bool.random(using: &generator) ? highlight : shadow
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(tone.opacity(.random(in: 0.10...0.22, using: &generator)))
                )
            }

            for index in 0..<strokeCount {
                let y = size.height * CGFloat(index) / CGFloat(strokeCount)
                let height = size.height / CGFloat(strokeCount) * CGFloat.random(in: 0.5...2.4, using: &generator)
                let inset = size.width * CGFloat.random(in: -0.1...0.32, using: &generator)
                let width = size.width * CGFloat.random(in: 0.3...1.05, using: &generator)

                let rect = CGRect(x: inset, y: y + generator.jitter(height), width: width, height: height)
                let tone = Bool.random(using: &generator) ? highlight : shadow

                // A stroke is drawn twice, the second copy offset and fainter,
                // so its edge is soft on one side and crisp on the other — the
                // ridge a brush leaves behind.
                context.fill(
                    Path(roundedRect: rect, cornerRadius: height / 2),
                    with: .color(tone.opacity(.random(in: 0.10...0.34, using: &generator)))
                )
                context.fill(
                    Path(roundedRect: rect.offsetBy(dx: 0, dy: height * 0.45), cornerRadius: height / 2),
                    with: .color(tone.opacity(.random(in: 0.04...0.14, using: &generator)))
                )
            }
        }
        .drawingGroup()
    }
}

// MARK: - View sugar

extension View {
    /// Paints a shape and draws the ink outline every painted surface carries.
    func painted<S: Shape>(
        _ shape: S,
        fill: Color,
        outline: Color = Theme.Palette.ink,
        lineWidth: CGFloat = Theme.Metrics.inkStroke
    ) -> some View {
        background(shape.fill(fill))
            .overlay(shape.stroke(outline, lineWidth: lineWidth))
            .clipShape(shape)
    }
}
