import SwiftUI
import AVFoundation

/// A muted, gaplessly-looping video layer for the onboarding hero screen.
/// `AVPlayerLooper` (not just `actionAtItemEnd = .none` + a notification
/// observer) is what gets a seamless loop with no visible restart flash.
struct VideoBackground: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerContainerView {
        PlayerContainerView(url: url)
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

    final class PlayerContainerView: UIView {
        private let queuePlayer = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private let playerLayer = AVPlayerLayer()

        init(url: URL) {
            super.init(frame: .zero)
            let item = AVPlayerItem(url: url)
            queuePlayer.isMuted = true
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            playerLayer.player = queuePlayer
            playerLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer)
            queuePlayer.play()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}
