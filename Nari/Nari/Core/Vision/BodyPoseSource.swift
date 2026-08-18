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
}

extension BodyPoseSource {
    @MainActor func attachPreview(_ layer: AVCaptureVideoPreviewLayer) {}
}
