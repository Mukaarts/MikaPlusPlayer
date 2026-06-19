import Foundation
import AVKit
import SwiftUI
import Combine

/// AVKit-basierte Engine. Spielt HLS (.m3u8) und gängige Container, aber KEINE
/// rohen MPEG-TS-Streams (.ts) – dafür siehe `VLCPlaybackEngine`.
@MainActor
@Observable
final class AVKitPlaybackEngine: PlaybackEngine {
    private(set) var state: PlaybackState = .idle

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var statusObserver: AnyCancellable?
    @ObservationIgnored private var errorObserver: AnyCancellable?

    func load(_ url: URL) {
        state = .loading
        let item = AVPlayerItem(url: url)
        observe(item)
        player.replaceCurrentItem(with: item)
        player.play()
    }

    func play() { player.play() }
    func pause() { player.pause() }

    func makePlayerView() -> AnyView {
        AnyView(VideoPlayer(player: player).ignoresSafeArea())
    }

    // MARK: - Status-Beobachtung

    private func observe(_ item: AVPlayerItem) {
        statusObserver = item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.state = .playing
                case .failed:
                    let message = item.error?.localizedDescription
                        ?? "Der Stream konnte nicht geladen werden."
                    self.state = .failed(message)
                case .unknown:
                    self.state = .loading
                @unknown default:
                    self.state = .loading
                }
            }

        // Laufzeitfehler während der Wiedergabe (z. B. Netzwerkabbruch).
        errorObserver = NotificationCenter.default
            .publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                self?.state = .failed(err?.localizedDescription
                    ?? "Wiedergabe wurde unterbrochen.")
            }
    }

    deinit {
        statusObserver?.cancel()
        errorObserver?.cancel()
    }
}
