import CoreGraphics
import Foundation

/// Turns raw camera frames into the three answers `RunEngine` needs.
///
/// This is the only place the pixel-level work and the game rules meet. The
/// engine never sees a joint, and the detectors never see the score.
struct MotionTracker {

    private var ngayog = NgayogDetector()
    private var squat = SquatDetector()
    private var steps = StepDetector()

    /// Markers for whichever pose is currently cued, empty the rest of the time.
    private(set) var markers: [PoseEvaluation.Marker] = []
    /// The most recent reading of where the player is.
    private(set) var bodyFrame: BodyFrame?
    /// Feet that landed on the most recent frame, for the view to spark at.
    private(set) var lastSteps: [Step] = []
    /// How many of the nine points are in place, for the "3 of 9" style readout.
    private(set) var matchedPointCount = 0

    var headTilt: Double { ngayog.tilt }
    var squatDepth: Double { squat.depth }

    /// Feeds one frame in. `cuedPose` is non-nil only during a Freeze.
    mutating func read(
        _ snapshot: BodyPoseSnapshot,
        delta: Double,
        cuedPose: PoseDefinition?,
        rules: RunRules
    ) -> RunInput {
        var input = RunInput()

        squat.update(snapshot, delta: delta)
        input.isSquatting = squat.isSquatting
        input.squatBegan = squat.didStartSquat

        let frame = BodyFrame(snapshot: snapshot)
        bodyFrame = frame

        // Hands, feet and hips go to the loop in image space, because that is
        // where the flowers are: pinned to the room rather than to the player.
        input.catchPositions = [BodyJoint.leftWrist, .rightWrist, .leftAnkle, .rightAnkle]
            .compactMap { snapshot.position(of: $0) }
        input.playerCenter = frame?.hipCenter
        if snapshot.imageSize.width > 0 {
            input.frameAspect = snapshot.imageSize.height / snapshot.imageSize.width
        }

        // The march is the walk now, so a footfall — not a head tilt — is
        // what pays out. `ngayog` still runs because the HUD reads its tilt.
        lastSteps = steps.update(snapshot, delta: delta, rules: rules)
        _ = ngayog.update(snapshot)
        input.completedNgayogCycle = !lastSteps.isEmpty

        guard let cuedPose else {
            markers = []
            matchedPointCount = 0
            return input
        }

        let evaluation = PoseEvaluator.evaluate(snapshot: snapshot, definition: cuedPose)
        markers = evaluation.markers
        matchedPointCount = evaluation.markers.filter(\.isCorrect).count
        input.matchesCuedPose = evaluation.isCorrect
        return input
    }

    /// Called when a session restarts, so a new run does not inherit the old
    /// run's standing height or half-finished tilt.
    mutating func reset() {
        ngayog.reset()
        squat.reset()
        steps.reset()
        markers = []
        matchedPointCount = 0
        bodyFrame = nil
        lastSteps = []
    }
}
