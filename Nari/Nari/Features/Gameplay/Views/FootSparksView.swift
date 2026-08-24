import SwiftUI

/// The sparks thrown off where a foot lands.
///
/// Ngayog is a walk, and until now the walk was the one move with no feedback
/// at all — the meter ticked up somewhere off to the side and nothing happened
/// where the player was actually looking. A burst under each foot puts the
/// reward where the movement is.
struct FootSparksView: View {
    let sparks: [FootSpark]
    let mapper: CameraFrameMapper

    var body: some View {
        Canvas { context, size in
            for spark in sparks {
                draw(spark, in: &context, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ spark: FootSpark, in context: inout GraphicsContext, size: CGSize) {
        let center = mapper.point(spark.position)
        let progress = spark.progress
        // Fast out of the ground, then easing as it dies.
        let eased = 1 - pow(1 - progress, 2.2)
        let fade = 1 - progress

        // Everything random about this burst comes off its own seed, read in a
        // fixed order, so the shape is settled the moment the foot lands and
        // stays put while it burns. A Canvas redraws every frame; drawing fresh
        // numbers here instead would make the spokes crawl.
        var shape = SeededGenerator(seed: spark.seed)
        let spokes = Int.random(in: 5...9, using: &shape)
        let turn = Double.random(in: 0..<(2 * .pi), using: &shape)
        let spread = Double.random(in: 0.85...1.3, using: &shape)
        let squash = Double.random(in: 0.38...0.56, using: &shape)
        let reaches = (0..<spokes).map { _ in Double.random(in: 0.55...1.75, using: &shape) }
        let hot = (0..<spokes).map { _ in Bool.random(using: &shape) }

        // Scaled off the frame rather than fixed, so a spark is the same size
        // against the player whatever the preview is scaled to.
        let unit = mapper.length(0.055) * spread
        guard unit > 0 else { return }

        // The glow on the ground underneath. Tighter and hotter than a soft
        // halo: this has to read against a bright room as well as a dark one.
        let glowRadius = unit * (0.45 + eased * 1.05)
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - glowRadius,
                y: center.y - glowRadius * 0.45,
                width: glowRadius * 2,
                height: glowRadius * 0.9
            )),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.95 * fade),
                    Theme.Palette.ochreLight.opacity(0.9 * fade),
                    Theme.Palette.cueOrange.opacity(0.5 * fade),
                    Theme.Palette.cueOrange.opacity(0),
                ]),
                center: center,
                startRadius: 0,
                endRadius: glowRadius
            )
        )

        // A white hot core for the first instant, which is what sells it as a
        // strike rather than a stain.
        let coreFade = max(0, 1 - progress * 2.6)
        if coreFade > 0 {
            let coreRadius = unit * 0.42 * coreFade
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - coreRadius,
                    y: center.y - coreRadius * 0.5,
                    width: coreRadius * 2,
                    height: coreRadius
                )),
                with: .color(.white.opacity(coreFade))
            )
        }

        // The ring of the impact spreading out.
        let ringRadius = unit * (0.2 + eased * 1.35)
        context.stroke(
            Path(ellipseIn: CGRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius * squash,
                width: ringRadius * 2,
                height: ringRadius * squash * 2
            )),
            with: .color(Theme.Palette.ochreLight.opacity(fade)),
            lineWidth: max(2.5, unit * 0.16 * fade)
        )

        // Sparks thrown off it, uneven in number, direction and length so no
        // two footfalls look like the same stamp.
        for index in 0..<spokes {
            let angle = turn + Double(index) / Double(spokes) * 2 * .pi
            let reach = unit * reaches[index] * eased
            let start = CGPoint(
                x: center.x + cos(angle) * reach * 0.45,
                y: center.y + sin(angle) * reach * 0.45 * squash * 2
            )
            let end = CGPoint(
                x: center.x + cos(angle) * reach,
                y: center.y + sin(angle) * reach * squash * 2 - unit * eased * 0.35
            )

            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(
                path,
                with: .color(hot[index]
                    ? Theme.Palette.ochreLight.opacity(fade)
                    : Theme.Palette.cueOrange.opacity(fade)),
                style: StrokeStyle(lineWidth: max(2.5, unit * 0.2 * fade), lineCap: .round)
            )
        }
    }
}

#Preview {
    let mapper = CameraFrameMapper(
        imageSize: CGSize(width: 1920, height: 1440),
        viewSize: CGSize(width: 900, height: 675),
        isMirrored: false
    )
    return FootSparksView(
        sparks: (0..<5).map { index in
            FootSpark(
                position: CGPoint(x: 0.14 + Double(index) * 0.18, y: 0.62),
                lifetime: 0.55,
                seed: UInt64(index) * 7919 + 13,
                age: 0.05
            )
        },
        mapper: mapper
    )
    .frame(width: 900, height: 675)
    .background(Theme.Palette.ink)
}
