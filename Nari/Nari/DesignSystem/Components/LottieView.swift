import SwiftUI
import AVKit

struct VideoView: UIViewControllerRepresentable {
    let name: String
    var fileExtension: String = "mp4"

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()

        if let url = Bundle.main.url(forResource: name, withExtension: fileExtension) {
            let player = AVPlayer(url: url)
            controller.player = player
            player.play()
            controller.showsPlaybackControls = false

            context.coordinator.player = player

            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var player: AVPlayer?

        @objc func playerDidFinishPlaying(notification: Notification) {
            player?.seek(to: CMTime.zero)
            player?.play()
        }
    }
}
