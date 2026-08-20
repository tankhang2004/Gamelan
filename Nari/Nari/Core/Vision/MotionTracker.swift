import CoreGraphics
import Foundation

/// Turns raw camera frames into the three answers `RunEngine` needs.
///
/// This is the only place the pixel-level work and the game rules meet. The
/// engine never sees a joint, and the detectors never see the score.
struct MotionTracker {

    private var ngayog = NgayogDetector()
    private var squat = SquatDetector()

    /// Markers for whichever pose is currently cued, empty the rest of the time.
    private(set) var markers: [PoseEvaluation.Marker] = []
    /// How many of the nine points are in place, for the "3 of 9" style readout.
    private(set) var matchedPointCount = 0

    var headTilt: Double { ngayog.tilt }
    var squatDepth: Double { squat.depth }

    /// Feeds one frame in. `cuedPose` is non-nil only during a Freeze.
    mutating func read(
        _ snapshot: BodyPoseSnapshot,
        delta: Double,
        cuedPose: PoseDefinition?
    ) -> RunInput {
        var input = RunInput()

        input.completedNgayogCycle = ngayog.update(snapshot)

        squat.update(snapshot, delta: delta)
        input.isSquatting = squat.isSquatting

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
        markers = []
        matchedPointCount = 0
    }
}
