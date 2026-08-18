import CoreGraphics
import Foundation

/// Converts between camera coordinates and *body space*.
///
/// Body space puts the origin at the hip centre and measures everything in
/// torso lengths, so a pose definition keeps working whether the player is
/// close to the camera or far away, tall or small, standing left or right of
/// centre. Comparing raw camera coordinates instead would only ever match a
/// player standing in exactly the same spot as whoever recorded the pose.
///
/// Axes match the camera image: x grows to the right, y grows downwards. The
/// frame is deliberately not rotated to the player's torso, so leaning to one
/// side still reads as an error rather than being normalised away.
struct BodyFrame: Sendable {
    let hipCenter: CGPoint
    let shoulderCenter: CGPoint
    /// Distance from hip centre to shoulder centre, the unit of body space.
    let torsoLength: CGFloat

    init?(snapshot: BodyPoseSnapshot) {
        guard let leftHip = snapshot.position(of: .leftHip),
              let rightHip = snapshot.position(of: .rightHip),
              let leftShoulder = snapshot.position(of: .leftShoulder),
              let rightShoulder = snapshot.position(of: .rightShoulder)
        else { return nil }

        let hips = CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
        let shoulders = CGPoint(
            x: (leftShoulder.x + rightShoulder.x) / 2,
            y: (leftShoulder.y + rightShoulder.y) / 2
        )
        let torso = hypot(shoulders.x - hips.x, shoulders.y - hips.y)

        // A torso shorter than this means the player is too far away or the
        // detection collapsed; scoring against it would be noise.
        guard torso > 0.04 else { return nil }

        hipCenter = hips
        shoulderCenter = shoulders
        torsoLength = torso
    }

    /// Camera position to body space.
    func normalize(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x - hipCenter.x) / torsoLength,
            y: (point.y - hipCenter.y) / torsoLength
        )
    }

    /// Body space back to camera position, used to draw where a joint *should*
    /// be for the pose the player is being asked to hold.
    func denormalize(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: hipCenter.x + point.x * torsoLength,
            y: hipCenter.y + point.y * torsoLength
        )
    }
}
