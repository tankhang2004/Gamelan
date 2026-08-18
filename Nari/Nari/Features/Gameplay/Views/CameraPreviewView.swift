import AVFoundation
import SwiftUI

/// Live camera preview, mirrored so the player reads it like a mirror.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// Handed back so the capture service can set the preview's rotation to
    /// match the frames it analyses.
    let onPreviewReady: (AVCaptureVideoPreviewLayer) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        onPreviewReady(view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // A layout pass follows every rotation, so this is where the preview
        // picks up a new angle without waiting for a notification.
        onPreviewReady(uiView.previewLayer)
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// Maps normalized joint positions onto the preview, matching how
/// `.resizeAspectFill` crops the picture.
struct CameraFrameMapper {
    let imageSize: CGSize
    let viewSize: CGSize
    /// The preview is mirrored while the analysed frames are not, so x has to
    /// be flipped to draw a marker over the right body part.
    let isMirrored: Bool

    var isUsable: Bool {
        imageSize.width > 0 && imageSize.height > 0 && viewSize.width > 0 && viewSize.height > 0
    }

    func point(_ normalized: CGPoint) -> CGPoint {
        guard isUsable else { return .zero }

        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let displayed = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (viewSize.width - displayed.width) / 2,
            y: (viewSize.height - displayed.height) / 2
        )

        let x = isMirrored ? 1 - normalized.x : normalized.x
        return CGPoint(
            x: origin.x + x * displayed.width,
            y: origin.y + normalized.y * displayed.height
        )
    }

    /// Length in view points of a distance given in normalized image width.
    func length(_ normalized: CGFloat) -> CGFloat {
        guard isUsable else { return 0 }
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        return normalized * imageSize.width * scale
    }
}
