import Foundation
import SwiftUI

/// Klassifiziert einen Stream anhand der URL, um die passende Engine zu wählen.
enum StreamType {
    /// HLS (.m3u8) – wird von AVPlayer nativ unterstützt.
    case hls
    /// Roher MPEG-TS (.ts) – AVPlayer kann das NICHT, benötigt VLCKit.
    case transportStream
    /// Unbekannt/anderes (mp4, mkv, …) – Versuch über AVPlayer als Default.
    case other

    init(url: URL) {
        switch url.pathExtension.lowercased() {
        case "m3u8", "m3u": self = .hls
        case "ts", "mpegts", "mts", "m2ts": self = .transportStream
        default: self = .other
        }
    }
}

/// Wiedergabezustand, plattform- und engine-unabhängig.
enum PlaybackState: Equatable {
    case idle
    case loading
    case playing
    case failed(String)
}

/// Gemeinsame Schnittstelle aller Wiedergabe-Engines (AVKit, VLCKit, …).
///
/// Der gesamte App-Code spricht nur dieses Protokoll an. Eine neue Engine
/// einzuhängen bedeutet: Klasse erstellen + in `PlaybackEngineFactory`
/// registrieren – kein anderer Code muss angefasst werden.
@MainActor
protocol PlaybackEngine: AnyObject, Observable {
    var state: PlaybackState { get }
    /// Pausiert? Getrennt nachgehalten – `PlaybackState` kennt bewusst kein `.paused`.
    var isPaused: Bool { get }
    /// Stummgeschaltet (unabhängig vom Lautstärke-Wert).
    var isMuted: Bool { get }
    /// Lautstärke, normalisiert auf 0…1 (engine-unabhängig).
    var volume: Double { get }

    func load(_ url: URL)
    func play()
    func pause()
    /// Schaltet zwischen Wiedergabe und Pause um (anhand `isPaused`).
    func togglePlayPause()
    /// Schaltet die Stummschaltung um.
    func toggleMute()
    /// Setzt die Stummschaltung deterministisch (idempotent). Für Multiview-Audio-Fokus,
    /// wo `toggleMute()` bei mehrfachen Fokuswechseln aus dem Tritt geraten könnte.
    func setMuted(_ muted: Bool)
    /// Setzt die Lautstärke; clamped auf 0…1 und hebt Stummschaltung bei Werten > 0 auf.
    func setVolume(_ value: Double)
    /// Liefert die SwiftUI-Oberfläche für diese Engine (VideoPlayer bzw.
    /// ein in SwiftUI eingebetteter VLC-Drawable-View).
    func makePlayerView() -> AnyView
}

/// Wählt die passende Engine für einen Stream.
enum PlaybackEngineFactory {
    @MainActor
    static func engine(for url: URL) -> any PlaybackEngine {
        switch StreamType(url: url) {
        case .transportStream:
            // Rohe TS-Streams brauchen VLCKit. Wenn VLCKit nicht eingebunden
            // ist, fällt `makeVLCEngine` auf AVKit zurück (best effort).
            return makeVLCEngine() ?? AVKitPlaybackEngine()
        case .hls, .other:
            return AVKitPlaybackEngine()
        }
    }

    /// Erzeugt eine VLC-Engine, sofern VLCKit zur Compile-Zeit verfügbar ist.
    @MainActor
    private static func makeVLCEngine() -> (any PlaybackEngine)? {
        #if canImport(VLCKitSPM) || canImport(MobileVLCKit) || canImport(VLCKit)
        return VLCPlaybackEngine()
        #else
        return nil
        #endif
    }
}
