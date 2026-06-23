import XCTest
@testable import MikaPlusPlayer

/// Prüft die engine-unabhängige Steuerungs-Logik (Lautstärke/Stumm/Play-Pause),
/// die hinter den neuen Tastatur-Shortcuts steckt. Getestet an `AVKitPlaybackEngine`,
/// da diese ohne Drittpaket auf jeder Plattform instanziierbar ist.
@MainActor
final class PlaybackEngineTests: XCTestCase {

    /// Lautstärke wird auf 0…1 begrenzt.
    func testSetVolumeClampsToUnitRange() {
        let engine = AVKitPlaybackEngine()
        engine.setVolume(1.5)
        XCTAssertEqual(engine.volume, 1.0, accuracy: 0.0001)
        engine.setVolume(-0.5)
        XCTAssertEqual(engine.volume, 0.0, accuracy: 0.0001)
        engine.setVolume(0.42)
        XCTAssertEqual(engine.volume, 0.42, accuracy: 0.0001)
    }

    /// Eine Lautstärke > 0 hebt eine bestehende Stummschaltung auf.
    func testRaisingVolumeUnmutes() {
        let engine = AVKitPlaybackEngine()
        engine.toggleMute()
        XCTAssertTrue(engine.isMuted)
        engine.setVolume(0.5)
        XCTAssertFalse(engine.isMuted)
        XCTAssertEqual(engine.volume, 0.5, accuracy: 0.0001)
    }

    /// Stummschaltung schaltet hin und her.
    func testToggleMuteFlips() {
        let engine = AVKitPlaybackEngine()
        XCTAssertFalse(engine.isMuted)
        engine.toggleMute()
        XCTAssertTrue(engine.isMuted)
        engine.toggleMute()
        XCTAssertFalse(engine.isMuted)
    }

    /// Play/Pause-Umschaltung pflegt den `isPaused`-Zustand.
    func testTogglePlayPauseFlipsIsPaused() {
        let engine = AVKitPlaybackEngine()
        XCTAssertFalse(engine.isPaused)
        engine.togglePlayPause()
        XCTAssertTrue(engine.isPaused)
        engine.togglePlayPause()
        XCTAssertFalse(engine.isPaused)
    }
}
