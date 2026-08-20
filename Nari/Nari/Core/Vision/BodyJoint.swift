import Foundation

/// The skeleton joints the game reads from Vision.
///
/// Left and right are anatomical, as Vision reports them on the unmirrored
/// camera feed: the player's own left hand is `leftWrist`, even though it shows
/// up on the right-hand side of the mirrored picture the player sees.
enum BodyJoint: String, CaseIterable, Codable, Sendable {
    case nose
    case neck
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle

    /// The joint on the other side of the body, for mirroring a pose.
    var mirrored: BodyJoint {
        switch self {
        case .nose, .neck: self
        case .leftShoulder: .rightShoulder
        case .rightShoulder: .leftShoulder
        case .leftElbow: .rightElbow
        case .rightElbow: .leftElbow
        case .leftWrist: .rightWrist
        case .rightWrist: .leftWrist
        case .leftHip: .rightHip
        case .rightHip: .leftHip
        case .leftKnee: .rightKnee
        case .rightKnee: .leftKnee
        case .leftAnkle: .rightAnkle
        case .rightAnkle: .leftAnkle
        }
    }
}

/// The nine points a Freeze is scored against, and the only ones the game draws
/// a marker for. Everything else is read to work out where the body is, how big
/// it appears, and which way the head is tilted.
enum TrackedBodyPoint: String, CaseIterable, Codable, Identifiable, Sendable {
    case neck
    case leftWrist
    case rightWrist
    case leftElbow
    case rightElbow
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle

    var id: String { rawValue }

    var joint: BodyJoint {
        switch self {
        case .neck: .neck
        case .leftWrist: .leftWrist
        case .rightWrist: .rightWrist
        case .leftElbow: .leftElbow
        case .rightElbow: .rightElbow
        case .leftKnee: .leftKnee
        case .rightKnee: .rightKnee
        case .leftAnkle: .leftAnkle
        case .rightAnkle: .rightAnkle
        }
    }

    var mirrored: TrackedBodyPoint {
        switch self {
        case .neck: .neck
        case .leftWrist: .rightWrist
        case .rightWrist: .leftWrist
        case .leftElbow: .rightElbow
        case .rightElbow: .leftElbow
        case .leftKnee: .rightKnee
        case .rightKnee: .leftKnee
        case .leftAnkle: .rightAnkle
        case .rightAnkle: .leftAnkle
        }
    }
}
