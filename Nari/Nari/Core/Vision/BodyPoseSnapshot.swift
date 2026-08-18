import CoreGraphics
import Foundation

/// One joint as detected in a single camera frame.
struct DetectedJoint: Sendable {
    /// Normalized image position, origin top-left, x to the right, y downwards.
    /// Vision reports bottom-left origin; the camera service flips it once here
    /// so the rest of the app only ever deals with UIKit-style coordinates.
    let position: CGPoint
    let confidence: Float
}

/// Everything the game knows about the player in one camera frame.
struct BodyPoseSnapshot: Sendable {
    let joints: [BodyJoint: DetectedJoint]
    /// Pixel size of the frame the joints were detected in, needed to map
    /// normalized positions onto an aspect-filled preview.
    let imageSize: CGSize
    let timestamp: TimeInterval

    static let empty = BodyPoseSnapshot(joints: [:], imageSize: .zero, timestamp: 0)

    /// Joints below this confidence are treated as not detected at all.
    static let minimumConfidence: Float = 0.3

    func position(of joint: BodyJoint) -> CGPoint? {
        guard let detected = joints[joint], detected.confidence >= Self.minimumConfidence else {
            return nil
        }
        return detected.position
    }

    func hasAll(_ required: [BodyJoint]) -> Bool {
        required.allSatisfy { position(of: $0) != nil }
    }

    /// Joints that must be visible before the game will start: the five scored
    /// points plus the shoulders and hips used to size the body.
    static let requiredForPlay: [BodyJoint] = [
        .nose, .leftShoulder, .rightShoulder, .leftHip, .rightHip,
        .leftWrist, .rightWrist, .leftKnee, .rightKnee,
    ]

    /// True when every required joint is visible and sits inside the frame with
    /// a little margin, which is the closest we get to "head to toe is in shot".
    func isFullBodyInFrame(margin: CGFloat = 0.03) -> Bool {
        let ankles = [position(of: .leftAnkle), position(of: .rightAnkle)].compactMap { $0 }
        let points = Self.requiredForPlay.compactMap { position(of: $0) } + ankles
        guard points.count >= Self.requiredForPlay.count else { return false }

        return points.allSatisfy { point in
            point.x > margin && point.x < 1 - margin && point.y > margin && point.y < 1 - margin
        }
    }
}
