import Foundation
import SwiftData

/// Eine importierte M3U/M3U8-Playlist. Kann aus einer Remote-URL oder einer
/// lokalen Datei stammen. Beim Löschen werden alle zugehörigen Channels
/// kaskadierend mitentfernt.
@Model
final class Playlist {
    /// Stabile ID (nicht die SwiftData-`persistentModelID`), praktisch für Tests.
    var id: UUID
    var name: String
    /// Nur gesetzt, wenn die Playlist von einer Remote-URL stammt. Lokale Datei -> nil.
    var sourceURL: URL?
    var createdAt: Date
    /// Zeitpunkt des letzten erfolgreichen Refreshes (nur bei Remote-Playlists relevant).
    var lastRefreshed: Date?

    /// True, wenn die Playlist über die Xtream-Codes-API (player_api.php) befüllt
    /// wurde. Dann ist `sourceURL` die player_api-URL inkl. Zugangsdaten.
    var isXtream: Bool
    /// Gewähltes Xtream-Ausgabeformat ("m3u8"/"ts") – Basis für Stream-URLs beim Refresh.
    var xtreamOutput: String?

    /// Denormalisierte Anzahl der Sender – vermeidet das Faulten der gesamten
    /// `channels`-Relationship nur zum Zählen (relevant bei großen Playlists).
    var channelCount: Int

    @Relationship(deleteRule: .cascade, inverse: \Channel.playlist)
    var channels: [Channel]

    init(
        id: UUID = UUID(),
        name: String,
        sourceURL: URL? = nil,
        createdAt: Date = Date(),
        lastRefreshed: Date? = nil,
        isXtream: Bool = false,
        xtreamOutput: String? = nil,
        channelCount: Int = 0,
        channels: [Channel] = []
    ) {
        self.id = id
        self.name = name
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.lastRefreshed = lastRefreshed
        self.isXtream = isXtream
        self.xtreamOutput = xtreamOutput
        self.channelCount = channelCount
        self.channels = channels
    }

    /// True, wenn die Playlist von einer Remote-URL stammt und refreshbar ist.
    var isRemote: Bool { sourceURL != nil }
}
