@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import UIKit
import Vision

/// Reads the front camera and turns every frame into a `BodyPoseSnapshot`
/// using Vision's human body pose request.
///
/// Nothing is recorded: frames are analysed and dropped.
///
/// Unchecked because the state is split by queue rather than by actor: the
/// capture session is only touched on `sessionQueue`, Vision only on
/// `visionQueue`, and the preview layer only on the main actor.
final class CameraBodyPoseService: NSObject, BodyPoseSource, @unchecked Sendable {

    let snapshots: AsyncStream<BodyPoseSnapshot>
    private let continuation: AsyncStream<BodyPoseSnapshot>.Continuation

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.yuknari.camera.session")
    private let visionQueue = DispatchQueue(label: "com.yuknari.camera.vision")

    private let request = VNDetectHumanBodyPoseRequest()
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var orientationObserver: NSObjectProtocol?
    private var isConfigured = false

    var captureSession: AVCaptureSession? { session }

    override init() {
        var escapingContinuation: AsyncStream<BodyPoseSnapshot>.Continuation!
        snapshots = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { escapingContinuation = $0 }
        continuation = escapingContinuation
        super.init()
    }

    deinit {
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
        }
        continuation.finish()
    }

    // MARK: - Lifecycle

    func start() async throws {
        try await requestPermission()
        try await configureIfNeeded()

        sessionQueue.async { [session] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func requestPermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                throw BodyPoseSourceError.permissionDenied
            }
        default:
            throw BodyPoseSourceError.permissionDenied
        }
    }

    private func configureIfNeeded() async throws {
        guard !isConfigured else { return }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera)
        else { throw BodyPoseSourceError.cameraUnavailable }

        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard session.canAddInput(input), session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            throw BodyPoseSourceError.cameraUnavailable
        }

        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        session.addOutput(videoOutput)

        session.commitConfiguration()

        // The preview is mirrored because a dancer expects a mirror, but the
        // analysed frames are left unmirrored so Vision's left/right joint
        // labels stay anatomically correct. The view layer flips x when it
        // draws markers over the mirrored preview.
        if let connection = videoOutput.connection(with: .video) {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }

        await applyCurrentRotation()
        await observeOrientationChanges()
        isConfigured = true
    }

    // MARK: - Rotation

    /// Called by the view once the preview layer exists.
    @MainActor
    func attachPreview(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        applyRotation(Self.rotationAngle(for: Self.interfaceOrientation()))
    }

    @MainActor
    private func applyCurrentRotation() async {
        applyRotation(Self.rotationAngle(for: Self.interfaceOrientation()))
    }

    @MainActor
    private func observeOrientationChanges() async {
        guard orientationObserver == nil else { return }
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.applyRotation(Self.rotationAngle(for: Self.interfaceOrientation()))
            }
        }
    }

    /// Both the preview and the analysed frames get the same angle, so a joint
    /// drawn at a normalized position lands on the right body part.
    @MainActor
    private func applyRotation(_ angle: CGFloat) {
        if let connection = previewLayer?.connection, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }

        sessionQueue.async { [videoOutput] in
            guard let connection = videoOutput.connection(with: .video),
                  connection.isVideoRotationAngleSupported(angle)
            else { return }
            connection.videoRotationAngle = angle
        }
    }

    @MainActor
    private static func interfaceOrientation() -> UIInterfaceOrientation {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.interfaceOrientation ?? .landscapeRight
    }

    /// Angle that makes the camera upright for a given interface orientation.
    ///
    /// This reads the interface rather than gravity on purpose. The game asks
    /// the player to lay the iPad down on the floor, and a device lying flat
    /// cannot tell the accelerometer which way is up — which is what left the
    /// preview a quarter turn out. The interface is locked to landscape, so it
    /// always knows.
    private static func rotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .portrait: 90
        case .portraitUpsideDown: 270
        case .landscapeLeft: 180
        case .landscapeRight: 0
        default: 0
        }
    }
}

// MARK: - Frame processing

extension CameraBodyPoseService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // The capture connection already rotates the buffer to match the
        // interface, so Vision receives an upright, unmirrored image.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        let imageSize = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )

        guard let observation = request.results?.first else {
            continuation.yield(BodyPoseSnapshot(joints: [:], imageSize: imageSize, timestamp: nowSeconds()))
            return
        }

        continuation.yield(
            BodyPoseSnapshot(
                joints: Self.joints(from: observation),
                imageSize: imageSize,
                timestamp: nowSeconds()
            )
        )
    }

    private func nowSeconds() -> TimeInterval { CACurrentMediaTime() }

    private static func joints(from observation: VNHumanBodyPoseObservation) -> [BodyJoint: DetectedJoint] {
        var result: [BodyJoint: DetectedJoint] = [:]

        for joint in BodyJoint.allCases {
            guard let point = try? observation.recognizedPoint(joint.visionJointName) else { continue }
            result[joint] = DetectedJoint(
                // Vision uses a bottom-left origin; flip y once here so the rest
                // of the app can think in UIKit coordinates.
                position: CGPoint(x: point.location.x, y: 1 - point.location.y),
                confidence: point.confidence
            )
        }
        return result
    }
}

private extension BodyJoint {
    var visionJointName: VNHumanBodyPoseObservation.JointName {
        switch self {
        case .nose: .nose
        case .neck: .neck
        case .leftShoulder: .leftShoulder
        case .rightShoulder: .rightShoulder
        case .leftElbow: .leftElbow
        case .rightElbow: .rightElbow
        case .leftWrist: .leftWrist
        case .rightWrist: .rightWrist
        case .leftHip: .leftHip
        case .rightHip: .rightHip
        case .leftKnee: .leftKnee
        case .rightKnee: .rightKnee
        case .leftAnkle: .leftAnkle
        case .rightAnkle: .rightAnkle
        }
    }
}
