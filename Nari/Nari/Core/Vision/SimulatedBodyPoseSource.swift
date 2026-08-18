import AVFoundation
import CoreGraphics
import Foundation

/// A fake dancer, used on the simulator where there is no camera.
///
/// It stands with the arms down for a couple of seconds, then raises them into
/// agem and holds, so the calibration and the pose hold can both be exercised
/// without a device.
final class SimulatedBodyPoseSource: BodyPoseSource {

    let snapshots: AsyncStream<BodyPoseSnapshot>
    private let continuation: AsyncStream<BodyPoseSnapshot>.Continuation
    private var task: Task<Void, Never>?

    var captureSession: AVCaptureSession? { nil }

    init() {
        var escapingContinuation: AsyncStream<BodyPoseSnapshot>.Continuation!
        snapshots = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { escapingContinuation = $0 }
        continuation = escapingContinuation
    }

    deinit {
        task?.cancel()
        continuation.finish()
    }

    func start() async throws {
        guard task == nil else { return }
        let start = CACurrentMediaTime()

        task = Task { [continuation] in
            while !Task.isCancelled {
                let elapsed = CACurrentMediaTime() - start
                continuation.yield(Self.snapshot(at: elapsed))
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    // MARK: - Fake body

    private static let hipCenter = CGPoint(x: 0.5, y: 0.62)
    private static let torso: CGFloat = 0.16

    private static func snapshot(at elapsed: TimeInterval) -> BodyPoseSnapshot {
        // Arms down until 2s, raising until 4.5s, then held in agem.
        let raise = CGFloat(min(max((elapsed - 2) / 2.5, 0), 1))

        func body(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: hipCenter.x + x * torso, y: hipCenter.y + y * torso)
        }

        let wristX = 0.25 + (0.95 - 0.25) * raise
        let wristY = 0.85 + (-1.0 - 0.85) * raise
        let elbowX = 0.2 + (0.5 - 0.2) * raise
        let elbowY = 0.35 + (-1.0 - 0.35) * raise

        let positions: [BodyJoint: CGPoint] = [
            .nose: body(0, -1.38),
            .neck: body(0, -1.1),
            .leftShoulder: body(0.38, -1.0),
            .rightShoulder: body(-0.38, -1.0),
            .leftElbow: body(elbowX, elbowY),
            .rightElbow: body(-elbowX, elbowY),
            .leftWrist: body(wristX, wristY),
            .rightWrist: body(-wristX, wristY),
            .leftHip: body(0.24, 0),
            .rightHip: body(-0.24, 0),
            .leftKnee: body(0.35, 0.55),
            .rightKnee: body(-0.35, 0.55),
            .leftAnkle: body(0.3, 1.15),
            .rightAnkle: body(-0.3, 1.15),
        ]

        let joints = positions.mapValues { DetectedJoint(position: $0, confidence: 0.92) }
        return BodyPoseSnapshot(
            joints: joints,
            imageSize: CGSize(width: 1280, height: 720),
            timestamp: elapsed
        )
    }
}
