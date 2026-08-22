@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import OSLog
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

    /// Knows where the front camera physically sits on this iPad. Only ever
    /// read to work out `cameraMountingOffset`; see `updateMountingOffset()`.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    /// Degrees to add to the interface angle on this particular device, once
    /// it has been possible to measure it. Nil means "not measured yet", which
    /// falls back to assuming the camera is on the portrait edge.
    private var cameraMountingOffset: CGFloat?

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

        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: nil)

        await observeOrientationChanges()
        await applyCurrentRotation()
        isConfigured = true
    }

    // MARK: - Rotation

    /// Called by the view once the preview layer exists.
    @MainActor
    func attachPreview(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        applyRotation(uprightAngle())
    }

    @MainActor
    private func applyCurrentRotation() async {
        applyRotation(uprightAngle())
    }

    @MainActor
    private func observeOrientationChanges() async {
        guard orientationObserver == nil else { return }

        // Without this `UIDevice.current.orientation` stays `.unknown` and the
        // notification below never fires at all.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()

        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.applyRotation(self.uprightAngle())
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

    /// The angle that makes the camera upright right now: where the interface
    /// is pointing, plus wherever this iPad happens to keep its front camera.
    @MainActor
    private func uprightAngle() -> CGFloat {
        updateMountingOffset()

        let base = Self.baseRotationAngle(for: Self.interfaceOrientation())
        let angle = base + (cameraMountingOffset ?? 0)
        return angle.truncatingRemainder(dividingBy: 360)
    }

    /// Measures how far this device's camera is turned relative to the
    /// portrait-edge mounting `baseRotationAngle` assumes.
    ///
    /// Apple has moved the front camera between the short edge and the long
    /// edge across the iPad line, so one hardcoded table cannot be upright on
    /// every device — an iPad Air and a recent iPad Pro need angles a quarter
    /// turn apart for the same interface orientation.
    ///
    /// `RotationCoordinator` knows the difference, but it derives its answer
    /// from gravity, and an iPad lying flat on the floor — which is how this
    /// game is played — has no gravity vector to read. So it is sampled only
    /// while the device is being held somewhere it can actually resolve, and
    /// the result is kept as a constant of the hardware. Everything after that
    /// is computed from the interface alone, which is the one thing a device
    /// flat on the floor still knows.
    @MainActor
    private func updateMountingOffset() {
        guard let rotationCoordinator else { return }

        // While the interface is locked to landscape the device can be held in
        // portrait, and then the two disagree and the difference is not the
        // mounting. Only a frame where they agree measures the hardware.
        let interface = Self.interfaceOrientation()
        guard UIDevice.current.orientation.matches(interface) else { return }

        let measured = rotationCoordinator.videoRotationAngleForHorizonLevelPreview
        let base = Self.baseRotationAngle(for: interface)
        let offset = (measured - base).truncatingRemainder(dividingBy: 360)
        let normalized = offset < 0 ? offset + 360 : offset

        guard normalized != cameraMountingOffset else { return }
        cameraMountingOffset = normalized
        Logger.camera.info("Front camera mounting offset \(normalized, privacy: .public)deg (AVFoundation \(measured, privacy: .public)deg, interface \(base, privacy: .public)deg).")
    }

    /// Angle that makes the camera upright for a given interface orientation,
    /// on a device whose front camera sits on the portrait edge.
    ///
    /// This reads the interface rather than gravity on purpose. The game asks
    /// the player to lay the iPad down on the floor, and a device lying flat
    /// cannot tell the accelerometer which way is up — which is what left the
    /// preview a quarter turn out. The interface is locked to landscape, so it
    /// always knows. `updateMountingOffset()` corrects for the hardware.
    private static func baseRotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
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

extension Logger {
    static let camera = Logger(subsystem: "com.yuknari.Nari", category: "camera")
}

/// `UIDeviceOrientation` and `UIInterfaceOrientation` name the two landscapes
/// the opposite way round: turning the device left turns the interface right.
private extension UIDeviceOrientation {
    func matches(_ interface: UIInterfaceOrientation) -> Bool {
        switch self {
        case .portrait: interface == .portrait
        case .portraitUpsideDown: interface == .portraitUpsideDown
        case .landscapeLeft: interface == .landscapeRight
        case .landscapeRight: interface == .landscapeLeft
        default: false
        }
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
