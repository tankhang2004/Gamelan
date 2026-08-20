import AVFoundation
import CoreGraphics
import Foundation

/// A fake dancer, used on the simulator where there is no camera.
///
/// It cannot see the cues, so instead it performs all three moves on loops of
/// different lengths: a steady head tilt throughout, a squat every so often, and
/// a stretch of agem kanan. Because the loops drift against the interrupt timer,
/// a simulator run hits successes and failures on its own — which is what makes
/// the whole state machine walkable without a device.
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

    private static let hipCenter = CGPoint(x: 0.5, y: 0.55)
    private static let torso: CGFloat = 0.14

    private static let tiltPeriod: Double = 1.7
    private static let squatPeriod: Double = 11
    private static let squatDuration: Double = 1.4
    private static let agemPeriod: Double = 19
    private static let agemDuration: Double = 9

    private static func snapshot(at elapsed: TimeInterval) -> BodyPoseSnapshot {
        // Two seconds of standing still at the top, so calibration can finish
        // before the dancer starts moving around inside the frame.
        let settled = max(elapsed - 2, 0)

        let tilt = CGFloat(sin(settled / tiltPeriod * 2 * .pi)) * 0.22
        let squat = ramp(phase: settled.truncatingRemainder(dividingBy: squatPeriod), length: squatDuration) * 0.45
        let agem = ramp(phase: settled.truncatingRemainder(dividingBy: agemPeriod), length: agemDuration)

        func body(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: hipCenter.x + x * torso, y: hipCenter.y + (y + squat) * torso)
        }

        // Arms sweep from resting into agem kanan: right arm out level, left
        // hand in front of the chest.
        let rightWristX = -0.30 + (-1.05 + 0.30) * agem
        let rightWristY = 0.80 + (-0.95 - 0.80) * agem
        let rightElbowX = -0.28 + (-0.60 + 0.28) * agem
        let rightElbowY = 0.35 + (-0.90 - 0.35) * agem
        let leftWristX = 0.30 + (0.35 - 0.30) * agem
        let leftWristY = 0.80 + (-0.70 - 0.80) * agem
        let leftElbowX = 0.28 + (0.45 - 0.28) * agem
        let leftElbowY = 0.35 + (-0.30 - 0.35) * agem

        // Knees bend for both the squat and the agem mendak.
        let bend = squat + 0.10 * agem

        let positions: [BodyJoint: CGPoint] = [
            .nose: body(tilt, -1.38),
            .neck: body(tilt * 0.4, -1.05),
            .leftShoulder: body(0.38, -1.0),
            .rightShoulder: body(-0.38, -1.0),
            .leftElbow: body(leftElbowX, leftElbowY),
            .rightElbow: body(rightElbowX, rightElbowY),
            .leftWrist: body(leftWristX, leftWristY),
            .rightWrist: body(rightWristX, rightWristY),
            .leftHip: body(0.24, 0),
            .rightHip: body(-0.24, 0),
            .leftKnee: body(0.40, 0.60 - bend * 0.3),
            .rightKnee: body(-0.45, 0.60 - bend * 0.3),
            .leftAnkle: body(0.45, 1.35 - squat),
            .rightAnkle: body(-0.40, 1.35 - squat),
        ]

        let joints = positions.mapValues { DetectedJoint(position: $0, confidence: 0.92) }
        return BodyPoseSnapshot(
            joints: joints,
            imageSize: CGSize(width: 1280, height: 720),
            timestamp: elapsed
        )
    }

    /// Rises to 1 over the first fifth of `length`, holds, then falls back to 0.
    /// Outside `length` it is 0, so the move happens once per period.
    private static func ramp(phase: Double, length: Double) -> CGFloat {
        guard phase < length else { return 0 }
        let edge = length * 0.2
        if phase < edge { return CGFloat(phase / edge) }
        if phase > length - edge { return CGFloat((length - phase) / edge) }
        return 1
    }
}
