import CoreGraphics
import Foundation

/// Where one tracked point should sit for a pose to count as correct.
///
/// `x` and `y` are in body space: hip centre is (0, 0), one unit is the length
/// of the torso, x grows towards the image right and y grows downwards. So
/// `y: -1.0` is shoulder height and `x: 0.95` is about an arm's length out to
/// the player's left.
struct PoseTarget: Codable, Sendable {
    let point: TrackedBodyPoint
    let x: Double
    let y: Double
    /// How far the point may sit from the target, in torso lengths. Bigger is
    /// more forgiving; 0.4 is roughly a hand's width on a child.
    let tolerance: Double

    var position: CGPoint { CGPoint(x: x, y: y) }
}

/// An angle the body has to make, checked on top of the point positions.
///
/// Positions alone cannot express "the arms form one straight line", because a
/// player can hit both wrist targets with bent elbows. Angles catch that.
struct PoseRule: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// Angle of the line between two joints, measured against the
        /// horizontal. 0 is a level line; the direction does not matter, so a
        /// line running right-to-left also reads as 0.
        case lineAngle
        /// The angle at the middle joint of three, 0 to 180. 180 is a fully
        /// straight limb.
        case jointAngle
    }

    let kind: Kind
    /// Two joints for `lineAngle`; three for `jointAngle`, middle one is the
    /// corner.
    let joints: [BodyJoint]
    let targetDegrees: Double
    let toleranceDegrees: Double
    /// Markers that turn red when this rule is broken.
    let affects: [TrackedBodyPoint]
}

/// One pose the player is asked to hold.
struct PoseDefinition: Codable, Identifiable, Sendable {
    let id: String
    /// Display name per language code, for example `{"id": "Agem", "en": "Agem"}`.
    let names: [String: String]
    let instructions: [String: String]
    /// Seconds the pose has to be held before it counts.
    let holdSeconds: Double
    let targets: [PoseTarget]
    let rules: [PoseRule]
    /// Image set with the pose drawing shown in the side panel, if any.
    let artworkName: String?

    func name(for language: AppLanguage) -> String {
        names[language.rawValue] ?? names["en"] ?? id
    }

    func instruction(for language: AppLanguage) -> String {
        instructions[language.rawValue] ?? instructions["en"] ?? ""
    }
}
