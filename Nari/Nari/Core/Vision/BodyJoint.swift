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
}

/// The five points the game scores and draws a marker for. Everything else is
/// read only to work out where the body is and how big it appears.
enum TrackedBodyPoint: String, CaseIterable, Codable, Identifiable, Sendable {
    case head
    case leftWrist
    case rightWrist
    case leftKnee
    case rightKnee

    var id: String { rawValue }

    var joint: BodyJoint {
        switch self {
        case .head: .nose
        case .leftWrist: .leftWrist
        case .rightWrist: .rightWrist
        case .leftKnee: .leftKnee
        case .rightKnee: .rightKnee
        }
    }
}
