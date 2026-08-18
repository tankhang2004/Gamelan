import CoreGraphics
import Foundation

/// The result of checking one camera frame against one pose.
struct PoseEvaluation: Sendable {
    struct Marker: Identifiable, Sendable {
        let point: TrackedBodyPoint
        /// Where the joint actually is, in normalized image coordinates.
        let detected: CGPoint
        /// Where it should be for this pose, in normalized image coordinates.
        let target: CGPoint
        let isCorrect: Bool

        var id: String { point.rawValue }
    }

    let markers: [Marker]
    /// False when a tracked point could not be seen at all this frame.
    let hasAllPoints: Bool

    var isCorrect: Bool {
        hasAllPoints && !markers.isEmpty && markers.allSatisfy(\.isCorrect)
    }

    static let none = PoseEvaluation(markers: [], hasAllPoints: false)
}

/// Scores a camera frame against a pose definition.
enum PoseEvaluator {

    static func evaluate(snapshot: BodyPoseSnapshot, definition: PoseDefinition) -> PoseEvaluation {
        guard let frame = BodyFrame(snapshot: snapshot) else { return .none }

        let brokenRules = failingPoints(snapshot: snapshot, rules: definition.rules)

        var markers: [PoseEvaluation.Marker] = []
        var missing = false

        for target in definition.targets {
            let targetInImage = frame.denormalize(target.position)

            guard let detected = snapshot.position(of: target.point.joint) else {
                missing = true
                continue
            }

            let offset = frame.normalize(detected)
            let distance = hypot(offset.x - target.position.x, offset.y - target.position.y)
            let withinTolerance = distance <= target.tolerance
            let ruleSatisfied = !brokenRules.contains(target.point)

            markers.append(
                PoseEvaluation.Marker(
                    point: target.point,
                    detected: detected,
                    target: targetInImage,
                    isCorrect: withinTolerance && ruleSatisfied
                )
            )
        }

        return PoseEvaluation(markers: markers, hasAllPoints: !missing)
    }

    // MARK: - Rules

    private static func failingPoints(
        snapshot: BodyPoseSnapshot,
        rules: [PoseRule]
    ) -> Set<TrackedBodyPoint> {
        var failing: Set<TrackedBodyPoint> = []

        for rule in rules where !isSatisfied(rule, in: snapshot) {
            failing.formUnion(rule.affects)
        }
        return failing
    }

    private static func isSatisfied(_ rule: PoseRule, in snapshot: BodyPoseSnapshot) -> Bool {
        switch rule.kind {
        case .lineAngle:
            guard rule.joints.count == 2,
                  let a = snapshot.position(of: rule.joints[0]),
                  let b = snapshot.position(of: rule.joints[1])
            else { return false }

            let angle = lineAngle(from: a, to: b)
            // A line has no direction, so 175 degrees and -5 degrees describe
            // the same slope. Comparing modulo 180 keeps both readings valid.
            return angularDifference(angle, rule.targetDegrees, modulo: 180) <= rule.toleranceDegrees

        case .jointAngle:
            guard rule.joints.count == 3,
                  let a = snapshot.position(of: rule.joints[0]),
                  let vertex = snapshot.position(of: rule.joints[1]),
                  let b = snapshot.position(of: rule.joints[2])
            else { return false }

            let angle = interiorAngle(a: a, vertex: vertex, b: b)
            return abs(angle - rule.targetDegrees) <= rule.toleranceDegrees
        }
    }

    /// Slope of a line in degrees, 0 for level. Image y grows downwards, so it
    /// is negated to make "up" positive, the way a person would read it.
    private static func lineAngle(from a: CGPoint, to b: CGPoint) -> Double {
        Double(atan2(-(b.y - a.y), b.x - a.x)) * 180 / .pi
    }

    private static func interiorAngle(a: CGPoint, vertex: CGPoint, b: CGPoint) -> Double {
        let v1 = CGPoint(x: a.x - vertex.x, y: a.y - vertex.y)
        let v2 = CGPoint(x: b.x - vertex.x, y: b.y - vertex.y)

        let dot = v1.x * v2.x + v1.y * v2.y
        let magnitude = hypot(v1.x, v1.y) * hypot(v2.x, v2.y)
        guard magnitude > 0 else { return 0 }

        let cosine = max(-1, min(1, dot / magnitude))
        return Double(acos(cosine)) * 180 / .pi
    }

    private static func angularDifference(_ a: Double, _ b: Double, modulo: Double) -> Double {
        let difference = (a - b).truncatingRemainder(dividingBy: modulo)
        let positive = difference < 0 ? difference + modulo : difference
        return min(positive, modulo - positive)
    }
}
