import Foundation
import SwiftUI

// VLCKit kann je nach Bezugsquelle unter verschiedenen Modulnamen vorliegen:
//   - SwiftPM-Binärpaket (tylerjonesio/vlckit-spm): VLCKitSPM  (iOS + macOS)
//   - CocoaPods iOS/tvOS:                           MobileVLCKit
//   - CocoaPods macOS:                              VLCKit
// Der gesamte Inhalt dieser Datei ist hinter `canImport` gekapselt, damit die
// App auch OHNE eingebundenes VLCKit kompiliert (Fallback: AVKit).
#if canImport(VLCKitSPM)
import VLCKitSPM
#elseif canImport(MobileVLCKit)
import MobileVLCKit
#elseif canImport(VLCKit)
import VLCKit
#endif

#if canImport(VLCKitSPM) || canImport(MobileVLCKit) || canImport(VLCKit)

/// VLCKit-basierte Engine. Spielt – im Gegensatz zu AVPlayer – auch rohe
/// MPEG-TS-Streams (.ts) sowie viele weitere Formate.
@MainActor
@Observable
final class VLCPlaybackEngine: NSObject, PlaybackEngine {
    private(set) var state: PlaybackState = .idle
    private(set) var isPaused = false
    private(set) var volume: Double = 1.0
    private(set) var isMuted = false

    @ObservationIgnored private let mediaPlayer = VLCMediaPlayer()
    // Der View, auf den VLC rendert. Wird vom Representable gesetzt.
    @ObservationIgnored fileprivate let drawableView = VLCDrawableView()

    override init() {
        super.init()
        mediaPlayer.delegate = self
        mediaPlayer.drawable = drawableView
    }

    func load(_ url: URL) {
        state = .loading
        let media = VLCMedia(url: url)
        mediaPlayer.media = media
        mediaPlayer.play()
        isPaused = false
    }

    func play() { mediaPlayer.play(); isPaused = false }
    func pause() { if mediaPlayer.isPlaying { mediaPlayer.pause() }; isPaused = true }
    func togglePlayPause() { isPaused ? play() : pause() }

    func setVolume(_ value: Double) {
        volume = min(1, max(0, value))
        if volume > 0 { isMuted = false }
        applyAudio()
    }

    func toggleMute() { isMuted.toggle(); applyAudio() }

    /// Wendet `volume`/`isMuted` auf den VLC-Audiokanal an. `mediaPlayer.audio` ist
    /// vor Wiedergabestart oft `nil`, daher wird dies auch beim Übergang nach `.playing`
    /// erneut aufgerufen (siehe Delegate), damit die Soll-Werte greifen.
    private func applyAudio() {
        guard let audio = mediaPlayer.audio else { return }
        audio.volume = Int32(volume * 100)
        // VLCAudio: @property (getter=isMuted) BOOL muted; -> in Swift settable als isMuted.
        audio.isMuted = isMuted
    }

    func makePlayerView() -> AnyView {
        AnyView(VLCPlayerSurface(view: drawableView).ignoresSafeArea())
    }
}

// MARK: - VLCMediaPlayerDelegate

extension VLCPlaybackEngine: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        // Delegate-Callbacks kommen nicht garantiert auf dem MainActor – den
        // Player-State daher erst innerhalb des MainActor-Task auslesen.
        Task { @MainActor in
            switch self.mediaPlayer.state {
            case .playing, .buffering, .esAdded:
                self.state = .playing
                // Audiokanal existiert jetzt – Soll-Lautstärke/Stumm anwenden.
                self.applyAudio()
            case .opening:
                self.state = .loading
            case .error:
                self.state = .failed("VLC konnte den Stream nicht abspielen.")
            case .stopped, .ended:
                self.state = .idle
            default:
                break
            }
        }
    }
}

// MARK: - Plattform-Brücke (UIView / NSView)

#if os(iOS)
typealias VLCDrawableView = UIView

/// Bettet den VLC-Drawable-View in SwiftUI ein (iOS).
private struct VLCPlayerSurface: UIViewRepresentable {
    let view: VLCDrawableView
    func makeUIView(context: Context) -> VLCDrawableView {
        view.backgroundColor = .black
        return view
    }
    func updateUIView(_ uiView: VLCDrawableView, context: Context) {}
}

#elseif os(macOS)
typealias VLCDrawableView = NSView

/// Bettet den VLC-Drawable-View in SwiftUI ein (macOS).
private struct VLCPlayerSurface: NSViewRepresentable {
    let view: VLCDrawableView
    func makeNSView(context: Context) -> VLCDrawableView {
        view.wantsLayer = true
        view.layer?.backgroundColor = .black
        return view
    }
    func updateNSView(_ nsView: VLCDrawableView, context: Context) {}
}
#endif

#endif // canImport VLCKit
