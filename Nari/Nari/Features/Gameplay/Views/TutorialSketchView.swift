import SwiftUI
import UIKit

/// The three drawings that explain where to put the iPad and where to stand.
enum TutorialStep: Int, CaseIterable, Identifiable {
    case placeDevice
    case stepBack
    case fullBody

    var id: Int { rawValue }

    var captionKey: LocalizedKey {
        switch self {
        case .placeDevice: .tutorialStep1
        case .stepBack: .tutorialStep2
        case .fullBody: .tutorialStep3
        }
    }

    /// Image set that replaces the drawn version once artwork is added.
    var artworkName: String {
        "TutorialStep\(rawValue + 1)"
    }
}

/// A pencil sketch of one tutorial step, drawn in code so it works before any
/// artwork exists. Drop a `TutorialStep1`/`2`/`3` image into the asset catalog
/// and it is used instead.
struct TutorialSketchView: View {
    let step: TutorialStep

    var body: some View {
        if let artwork = UIImage(named: step.artworkName) {
            Image(uiImage: artwork)
                .resizable()
                .scaledToFit()
        } else {
            Canvas { context, size in
                let sketch = Sketch(context: context, size: size)
                sketch.drawRoom()

                switch step {
                case .placeDevice: sketch.drawPlaceDevice()
                case .stepBack: sketch.drawStepBack()
                case .fullBody: sketch.drawFullBody()
                }
            }
        }
    }
}

/// Small drawing helper: everything is in fractions of the canvas, and every
/// line is stroked twice with a slight offset so it reads as pencil rather than
/// as a vector diagram.
private struct Sketch {
    let context: GraphicsContext
    let size: CGSize

    private let ink = Theme.Palette.pencil
    private let accent = Theme.Palette.cueOrange

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    private func stroke(_ path: Path, width: CGFloat = 3, color: Color? = nil) {
        let color = color ?? ink
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        context.stroke(path, with: .color(color.opacity(0.92)), style: style)
        context.stroke(
            path.offsetBy(dx: 1.4, dy: 1.1),
            with: .color(color.opacity(0.28)),
            style: StrokeStyle(lineWidth: width * 0.8, lineCap: .round, lineJoin: .round)
        )
    }

    private func line(_ from: CGPoint, _ to: CGPoint, width: CGFloat = 3, color: Color? = nil) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        stroke(path, width: width, color: color)
    }

    // MARK: - Shared scenery

    /// The corner of a room in one-point perspective, same as the reference
    /// sketch: back wall in the middle, floor opening towards the viewer.
    func drawRoom() {
        let backTopLeft = point(0.30, 0.10)
        let backTopRight = point(0.70, 0.10)
        let backBottomLeft = point(0.30, 0.58)
        let backBottomRight = point(0.70, 0.58)

        line(backTopLeft, backBottomLeft)
        line(backTopRight, backBottomRight)
        line(backBottomLeft, backBottomRight)

        line(backBottomLeft, point(0.06, 0.94))
        line(backBottomRight, point(0.94, 0.94))
    }

    private func drawDevice(center: CGPoint, width: CGFloat) {
        let height = width * 0.7
        let body = CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
        stroke(Path(roundedRect: body, cornerRadius: width * 0.08), width: 3.5)
        stroke(
            Path(roundedRect: body.insetBy(dx: width * 0.09, dy: height * 0.12), cornerRadius: 4),
            width: 1.6
        )
        // The little stand keeping the screen upright.
        line(
            CGPoint(x: center.x, y: body.maxY),
            CGPoint(x: center.x + width * 0.28, y: body.maxY + height * 0.35),
            width: 2.5
        )
    }

    private func drawPerson(feet: CGPoint, height: CGFloat, armsOut: Bool) {
        let headRadius = height * 0.11
        let head = CGPoint(x: feet.x, y: feet.y - height + headRadius)
        let neck = CGPoint(x: feet.x, y: head.y + headRadius * 1.2)
        let hip = CGPoint(x: feet.x, y: feet.y - height * 0.42)

        stroke(
            Path(ellipseIn: CGRect(
                x: head.x - headRadius,
                y: head.y - headRadius,
                width: headRadius * 2,
                height: headRadius * 2
            )),
            width: 3
        )
        line(neck, hip)

        let shoulder = CGPoint(x: feet.x, y: neck.y + height * 0.06)
        if armsOut {
            line(shoulder, CGPoint(x: feet.x - height * 0.26, y: shoulder.y - height * 0.02))
            line(shoulder, CGPoint(x: feet.x + height * 0.26, y: shoulder.y - height * 0.02))
        } else {
            line(shoulder, CGPoint(x: feet.x - height * 0.16, y: hip.y - height * 0.02))
            line(shoulder, CGPoint(x: feet.x + height * 0.16, y: hip.y - height * 0.02))
        }

        line(hip, CGPoint(x: feet.x - height * 0.13, y: feet.y))
        line(hip, CGPoint(x: feet.x + height * 0.13, y: feet.y))
    }

    private func drawArrow(from: CGPoint, to: CGPoint) {
        line(from, to, width: 3.5, color: accent)

        let angle = atan2(to.y - from.y, to.x - from.x)
        let headLength = size.height * 0.05
        for spread in [CGFloat.pi * 0.82, -CGFloat.pi * 0.82] {
            let tip = CGPoint(
                x: to.x + cos(angle + spread) * headLength,
                y: to.y + sin(angle + spread) * headLength
            )
            line(to, tip, width: 3.5, color: accent)
        }
    }

    // MARK: - Steps

    /// Frame 1: the iPad going down onto the floor.
    func drawPlaceDevice() {
        drawDevice(center: point(0.5, 0.72), width: size.width * 0.17)
        drawArrow(from: point(0.5, 0.36), to: point(0.5, 0.60))

        var floor = Path()
        floor.move(to: point(0.34, 0.86))
        floor.addLine(to: point(0.66, 0.86))
        context.stroke(
            floor,
            with: .color(ink.opacity(0.4)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 8])
        )
    }

    /// Frame 2: the player walking backwards away from the iPad.
    func drawStepBack() {
        drawDevice(center: point(0.5, 0.82), width: size.width * 0.12)
        drawPerson(feet: point(0.5, 0.66), height: size.height * 0.42, armsOut: false)
        drawArrow(from: point(0.72, 0.60), to: point(0.86, 0.78))

        for index in 0..<3 {
            let x = 0.60 + CGFloat(index) * 0.06
            var mark = Path()
            mark.move(to: point(x, 0.80))
            mark.addLine(to: point(x + 0.03, 0.80))
            context.stroke(
                mark,
                with: .color(ink.opacity(0.35)),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
        }
    }

    /// Frame 3: head to toe inside the camera view.
    func drawFullBody() {
        drawDevice(center: point(0.5, 0.88), width: size.width * 0.11)
        drawPerson(feet: point(0.5, 0.80), height: size.height * 0.62, armsOut: true)

        // The camera's field of view opening up from the device.
        var cone = Path()
        cone.move(to: point(0.5, 0.84))
        cone.addLine(to: point(0.20, 0.10))
        cone.move(to: point(0.5, 0.84))
        cone.addLine(to: point(0.80, 0.10))
        context.stroke(
            cone,
            with: .color(accent.opacity(0.55)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [10, 7])
        )

        // Brackets marking head and toe.
        let bracketWidth = size.width * 0.05
        for y in [CGFloat(0.14), CGFloat(0.82)] {
            line(point(0.5, y) + CGPoint(x: -bracketWidth, y: 0), point(0.5, y) + CGPoint(x: bracketWidth, y: 0), width: 3, color: accent)
        }
    }
}

private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

#Preview {
    HStack {
        ForEach(TutorialStep.allCases) { step in
            TutorialSketchView(step: step)
                .background(Theme.Palette.paper)
        }
    }
}
