@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import OSLog
import simd
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
    private var isConfigured = false

    /// Reads gravity to work out which way up the camera is, whatever the
    /// interface is doing. Both of its angles are observed; see the rotation
    /// section below.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservations: [NSKeyValueObservation] = []
    /// The layer `rotationCoordinator` was built around, so `attachPreview`
    /// can tell a genuinely new preview from the same one being handed back.
    private weak var coordinatorLayer: AVCaptureVideoPreviewLayer?

    /// The device, kept so the field of view can be changed while running.
    private var camera: AVCaptureDevice?
    private var fieldOfView: CameraFieldOfView = .standard
    /// Zoom that crops the widest format down to `standardDegrees`. 1 when the
    /// device has nothing wider to crop, which is what makes the toggle hide
    /// itself rather than pretend.
    private var standardZoomFactor: CGFloat = 1

    var supportsFieldOfViewChange: Bool { standardZoomFactor > 1.01 }

    /// Measured once from the first frame that carries a camera intrinsic
    /// matrix, then left alone.
    private var hasMeasuredIntrinsics = false

    var captureSession: AVCaptureSession? { session }

    override init() {
        var escapingContinuation: AsyncStream<BodyPoseSnapshot>.Continuation!
        snapshots = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { escapingContinuation = $0 }
        continuation = escapingContinuation
        super.init()
    }

    deinit {
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

        self.camera = camera

        // Off before the formats are read, for two reasons: Center Stage crops
        // in and pans to follow whoever it decides is the subject, which is
        // both a smaller field of view and a moving one, and while it is on the
        // widest formats are not offered at all.
        // Center Stage support is a property of each format, and the enabled
        // flag throws unless the app has taken control of it first.
        if camera.formats.contains(where: \.isCenterStageSupported) {
            AVCaptureDevice.centerStageControlMode = .app
            AVCaptureDevice.isCenterStageEnabled = false
        }

        session.beginConfiguration()
        // The format is chosen below rather than left to a preset, so the whole
        // sensor is available to crop out of.
        session.sessionPreset = .inputPriority

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

        if let format = Self.widestUsableFormat(for: camera) {
            try? camera.lockForConfiguration()
            camera.activeFormat = format

            // Activating a format resets the frame duration to that format's
            // default, which on the big sensor formats can be well under 30.
            // Pinned to 30 both ways: the loop reads a cue every frame, and
            // there is nothing to gain from 60 except heat.
            let thirty = CMTime(value: 1, timescale: 30)
            if format.videoSupportedFrameRateRanges.contains(where: {
                $0.minFrameDuration <= thirty && thirty <= $0.maxFrameDuration
            }) {
                camera.activeVideoMinFrameDuration = thirty
                camera.activeVideoMaxFrameDuration = thirty
            }

            // Rectifying an ultra wide lens means throwing away the edges that
            // bend out of the frame, so correction costs width — and width is
            // the whole point here.
            //
            // The barrel distortion that comes back is a real cost, not a free
            // one: an intrinsic matrix describes a pinhole lens, so handing it
            // to Vision does not model that distortion away. If joints start
            // landing off the body near the edges of the frame, this is the
            // line to put back.
            if camera.isGeometricDistortionCorrectionSupported {
                camera.isGeometricDistortionCorrectionEnabled = false
            }

            camera.unlockForConfiguration()

            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            Logger.camera.info(
                "Capturing \(size.width, privacy: .public)x\(size.height, privacy: .public), \(format.videoFieldOfView, privacy: .public) degrees across and \(Self.verticalFieldOfView(of: format), privacy: .public) down."
            )
        }

        session.commitConfiguration()

        configureZoomRange(for: camera)
        applyFieldOfView()

        // The preview is mirrored because a dancer expects a mirror, but the
        // analysed frames are left unmirrored so Vision's left/right joint
        // labels stay anatomically correct. The view layer flips x when it
        // draws markers over the mirrored preview.
        if let connection = videoOutput.connection(with: .video) {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false

            // The camera's own account of its geometry, attached per frame:
            // focal length and principal point in pixels. Better than the
            // format's nominal figure because it describes the buffer actually
            // being delivered, zoom and distortion correction included. Not
            // offered while video stabilisation is on, which is why this asks
            // rather than assumes.
            // Stabilisation works by keeping a margin in hand to shift the
            // picture around inside, so it is a crop by definition — and it
            // also switches intrinsic delivery off. The iPad is sitting on the
            // floor or a table, so there is nothing to stabilise anyway.
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .off
            }

            if connection.isCameraIntrinsicMatrixDeliverySupported {
                connection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }

        // Replaced by a layer-aware one in `attachPreview`; this one only has
        // to keep the analysed buffers level until the preview exists.
        await MainActor.run {
            rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: nil)
            observeRotationChanges()
        }
        isConfigured = true
    }

    // MARK: - Field of view

    func setFieldOfView(_ fieldOfView: CameraFieldOfView) {
        guard self.fieldOfView != fieldOfView else { return }
        self.fieldOfView = fieldOfView
        applyFieldOfView()
    }

    /// The format that fits the most player in, that Vision can still keep up
    /// with.
    ///
    /// Ranked on *vertical* field of view, not the horizontal one AVFoundation
    /// reports. The iPad is in landscape and the player is standing, so their
    /// height runs across the short side of the frame — height is what decides
    /// whether their feet are in shot, and width is never the constraint.
    ///
    /// The distinction is the whole game here. An iPad Air's front camera is
    /// 122 degrees across the diagonal of a 4:3 sensor, which works out at
    /// about 110 degrees horizontally and 94 vertically. The 16:9 video formats
    /// are that same sensor with the top and bottom cut off: still 110 across,
    /// but only 78 down. Both report the same `videoFieldOfView`, so ranking on
    /// it alone picks between them by accident and can easily take the one that
    /// sees a third less of the player.
    ///
    /// Resolution is deliberately not capped. The 1080p formats are not the
    /// full sensor scaled down, they are a crop out of the middle of it, so a
    /// cap on pixels is a cap on field of view — which is what was making the
    /// preview noticeably tighter than the system Camera app from the same
    /// spot. Cost is handled by the tie break instead: among formats that see
    /// equally much, the cheapest to run wins.
    private static func widestUsableFormat(for camera: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let candidates = camera.formats.filter { format in
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            // The floor matters as much as the cap did. Once the tie break
            // prefers the cheaper buffer, letting a 640x480 binned format into
            // the running means picking it — and a child three metres away in a
            // 640 wide frame is not enough pixels to find a wrist on.
            guard size.width >= 1280, format.videoFieldOfView > 0 else { return false }
            return format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 30 }
        }

        for format in candidates.sorted(by: { verticalFieldOfView(of: $0) > verticalFieldOfView(of: $1) }).prefix(4) {
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            Logger.camera.debug(
                "Candidate \(size.width, privacy: .public)x\(size.height, privacy: .public): \(format.videoFieldOfView, privacy: .public) across, \(verticalFieldOfView(of: format), privacy: .public) down."
            )
        }

        return candidates.max { first, second in
            let a = verticalFieldOfView(of: first)
            let b = verticalFieldOfView(of: second)
            // Half a degree apart is the same view; prefer the smaller buffer.
            guard abs(a - b) <= 0.5 else { return a < b }
            return pixelCount(of: first) > pixelCount(of: second)
        }
    }

    private static func pixelCount(of format: AVCaptureDevice.Format) -> Int {
        let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        return Int(size.width) * Int(size.height)
    }

    /// How far the format sees from top to bottom, in degrees.
    ///
    /// AVFoundation only publishes the horizontal angle, so this reconstructs
    /// the vertical one from the frame's shape: the two share a focal length,
    /// and the half angle tangents are in the same ratio as the sides.
    private static func verticalFieldOfView(of format: AVCaptureDevice.Format) -> Double {
        let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        guard size.width > 0, format.videoFieldOfView > 0 else { return 0 }

        let horizontal = Double(format.videoFieldOfView) * .pi / 180
        let aspect = Double(size.height) / Double(size.width)
        return 2 * atan(tan(horizontal / 2) * aspect) * 180 / .pi
    }

    /// Works out how far in the standard setting has to crop.
    ///
    /// Cropping by a factor narrows the view by that factor in *tangent* space,
    /// not in degrees, so the zoom for a target angle is the ratio of the half
    /// angle tangents. Clamped to what the device will actually accept.
    private func configureZoomRange(for camera: AVCaptureDevice) {
        let wideDegrees = camera.activeFormat.videoFieldOfView
        guard wideDegrees > CameraFieldOfView.standardDegrees else {
            standardZoomFactor = 1
            Logger.camera.info("Front camera is \(wideDegrees, privacy: .public) degrees across; no room to crop.")
            return
        }

        let half = { (degrees: Float) in tan(Double(degrees) * .pi / 360) }
        let factor = CGFloat(half(wideDegrees) / half(CameraFieldOfView.standardDegrees))
        standardZoomFactor = min(max(factor, 1), camera.maxAvailableVideoZoomFactor)

        Logger.camera.info(
            "Front camera \(wideDegrees, privacy: .public) degrees wide; standard crop is \(self.standardZoomFactor, privacy: .public)x."
        )
    }

    private func applyFieldOfView() {
        guard let camera else { return }
        let factor = fieldOfView == .wide ? camera.minAvailableVideoZoomFactor : standardZoomFactor

        sessionQueue.async {
            do {
                try camera.lockForConfiguration()
                camera.videoZoomFactor = min(max(factor, camera.minAvailableVideoZoomFactor), camera.maxAvailableVideoZoomFactor)
                camera.unlockForConfiguration()
            } catch {
                Logger.camera.error("Could not change the field of view: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Rotation

    /// Keeping the picture upright is handed to `RotationCoordinator` rather
    /// than worked out from the interface, because the interface is only ever
    /// told about orientations the app supports and only after it has finished
    /// rotating into them — neither of which describes where the camera is
    /// actually pointing right now. The coordinator reads gravity directly and
    /// publishes two angles: one that levels the preview and one that levels
    /// the buffers handed to Vision. This is the same mechanism the system
    /// Camera app uses, which is why its picture stays upright at any angle.
    ///
    /// Both angles are observed rather than polled, so a rotation is applied
    /// as it happens rather than on the next frame that thought to ask.

    /// Called by the view once the preview layer exists.
    ///
    /// Idempotent, and it has to be: the representable hands the layer back on
    /// every layout pass, not just the first. Rebuilding the coordinator each
    /// time re-registered a KVO observer that fires immediately, which set the
    /// connection's angle, which dirtied the layer, which brought on another
    /// layout pass — a loop that kept the whole gameplay stage too busy to
    /// settle into a new size when the device was turned.
    @MainActor
    func attachPreview(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer

        // Rebuilt around the layer: given one, the coordinator accounts for
        // how the preview itself is oriented on screen, not just how the
        // device is being held. The observers carry every later change, so
        // this only has to happen when the layer itself is new.
        //
        // Keyed off the layer the coordinator was actually built for rather
        // than off `previewLayer`, so a preview that appears before the camera
        // has finished configuring — which is the ordering on the tutorial
        // screen — is still picked up on the next pass instead of being
        // remembered as done.
        guard let camera, coordinatorLayer !== layer else { return }
        coordinatorLayer = layer
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: layer)
        observeRotationChanges()
    }

    @MainActor
    private func observeRotationChanges() {
        guard let rotationCoordinator else { return }
        rotationObservations.removeAll()

        rotationObservations.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] _, change in
                guard let angle = change.newValue else { return }
                Task { @MainActor in self?.applyPreviewRotation(angle) }
            }
        )

        rotationObservations.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] _, change in
                guard let angle = change.newValue else { return }
                Task { @MainActor in self?.applyCaptureRotation(angle) }
            }
        )
    }

    /// A Mac has no accelerometer, so the coordinator has no gravity to read
    /// and reports a flat zero — which leaves the built-in camera's picture
    /// upside down. A Mac window never rotates either, so the correction is a
    /// fixed constant of the hardware rather than anything to keep watching.
    private func levelled(_ angle: CGFloat) -> CGFloat {
        ProcessInfo.processInfo.isiOSAppOnMac ? 180 : angle
    }

    @MainActor
    private func applyPreviewRotation(_ rawAngle: CGFloat) {
        let angle = levelled(rawAngle)
        guard let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle)
        else { return }
        connection.videoRotationAngle = angle
    }

    /// The buffers Vision reads are levelled separately from the preview: the
    /// two angles agree while the device is upright but diverge once it is
    /// tilted, and a joint has to land on the body in the picture the player
    /// is looking at.
    @MainActor
    private func applyCaptureRotation(_ rawAngle: CGFloat) {
        let angle = levelled(rawAngle)
        sessionQueue.async { [videoOutput] in
            guard let connection = videoOutput.connection(with: .video),
                  connection.isVideoRotationAngleSupported(angle)
            else { return }
            connection.videoRotationAngle = angle
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

        let intrinsics = CMGetAttachment(
            sampleBuffer,
            key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
            attachmentModeOut: nil
        ) as? Data

        // Vision corrects for the lens when it is told what the lens is doing,
        // which matters more the wider the frame gets: on a 110 degree capture
        // a child at the edge is noticeably stretched, and their joints land
        // off the body without this.
        var options: [VNImageOption: Any] = [:]
        if let intrinsics {
            options[.cameraIntrinsics] = intrinsics
        }

        // The capture connection already rotates the buffer to match the
        // interface, so Vision receives an upright, unmirrored image.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: options)
        do {
            try handler.perform([request])
        } catch {
            return
        }

        let imageSize = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )

        measureIntrinsicsIfNeeded(intrinsics, imageSize: imageSize)

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

    /// Replaces the field of view worked out from the format's nominal numbers
    /// with the one the camera reports for the frames it is actually sending.
    ///
    /// `videoFieldOfView` is a single horizontal figure per format, and the
    /// vertical angle has to be reconstructed from the frame's shape assuming
    /// square pixels. The intrinsic matrix gives the focal length in pixels on
    /// both axes directly, so nothing has to be assumed and nothing has to be
    /// read off a spec sheet. It cannot choose the format — a format has to be
    /// active and delivering frames before it reports anything — so selection
    /// still runs on the nominal figures, and this corrects them afterwards.
    private func measureIntrinsicsIfNeeded(_ data: Data?, imageSize: CGSize) {
        guard !hasMeasuredIntrinsics,
              let camera,
              let data,
              data.count >= MemoryLayout<matrix_float3x3>.size
        else { return }

        hasMeasuredIntrinsics = true

        // Copied rather than loaded in place: `Data` gives no alignment promise
        // and this type wants sixteen bytes of it.
        var matrix = matrix_float3x3()
        _ = withUnsafeMutableBytes(of: &matrix) { data.copyBytes(to: $0) }

        let focalX = Double(matrix.columns.0.x)
        let focalY = Double(matrix.columns.1.y)
        guard focalX > 0, focalY > 0, imageSize.width > 0, imageSize.height > 0 else { return }

        // A zoom is a crop, and cropping scales the focal length in pixels by
        // the same factor, so dividing it back out recovers the uncropped lens.
        let zoom = max(Double(camera.videoZoomFactor), 0.0001)
        let degrees = { (side: Double, focal: Double) in
            2 * atan(side / (2 * focal / zoom)) * 180 / .pi
        }
        let horizontal = degrees(Double(imageSize.width), focalX)
        let vertical = degrees(Double(imageSize.height), focalY)

        Logger.camera.info(
            "Measured \(horizontal, privacy: .public) degrees across and \(vertical, privacy: .public) down at full width."
        )

        guard horizontal > Double(CameraFieldOfView.standardDegrees) else {
            standardZoomFactor = 1
            return
        }

        let half = { (angle: Double) in tan(angle * .pi / 360) }
        let factor = CGFloat(half(horizontal) / half(Double(CameraFieldOfView.standardDegrees)))
        standardZoomFactor = min(max(factor, 1), camera.maxAvailableVideoZoomFactor)
        Logger.camera.info("Standard crop corrected to \(self.standardZoomFactor, privacy: .public)x.")
    }

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
