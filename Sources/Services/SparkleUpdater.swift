#if os(macOS)
import Foundation
@preconcurrency import Sparkle

/// Dünner Wrapper um Sparkles `SPUStandardUpdaterController` – analog zu den
/// anderen Mika+ Apps. Nur macOS (Sparkle ist macOS-only, DMG-Distribution).
@MainActor
@Observable
final class SparkleUpdater {
    @ObservationIgnored private let controller: SPUStandardUpdaterController

    init() {
        // startingUpdater: true -> startet den geplanten Update-Check automatisch.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Ob aktuell nach Updates gesucht werden kann (für den Menü-Button).
    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    /// Manueller Update-Check (zeigt Sparkles UI mit Fortschritt/Release-Notes).
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
#endif
