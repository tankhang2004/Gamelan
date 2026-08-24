import AVFoundation
import Foundation

enum BodyPoseSourceError: LocalizedError {
    case permissionDenied
    case cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Camera access was denied."
        case .cameraUnavailable: "No usable camera on this device."
        }
    }
}

/// Where body poses come from. The game only ever talks to this protocol, so
/// the simulator can run the whole flow on a fake body without a camera.
protocol BodyPoseSource: AnyObject {
    /// Frames of detected joints, one per processed camera frame.
    var snapshots: AsyncStream<BodyPoseSnapshot> { get }
    /// The session to hand to the preview layer, or nil when there is no camera.
    var captureSession: AVCaptureSession? { get }

    func start() async throws
    func stop()

    /// Handed the layer showing the camera, so the source can keep the preview
    /// and the analysed frames rotated the same way.
    @MainActor func attachPreview(_ layer: AVCaptureVideoPreviewLayer)

    /// How much of the room to take in. Safe to call while running.
    func setFieldOfView(_ fieldOfView: CameraFieldOfView)

    /// True when this source can actually offer two different views. False on a
    /// device whose widest format is already no wider than the standard crop,
    /// and on the fake dancer, so the toggle can hide itself rather than sit
    /// there doing nothing.
    var supportsFieldOfViewChange: Bool { get }
}

extension BodyPoseSource {
    @MainActor func attachPreview(_ layer: AVCaptureVideoPreviewLayer) {}
    func setFieldOfView(_ fieldOfView: CameraFieldOfView) {}
    var supportsFieldOfViewChange: Bool { false }
}
