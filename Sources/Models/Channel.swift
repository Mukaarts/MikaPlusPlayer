import Foundation
import SwiftData

/// Ein einzelner Sender / Stream-Eintrag innerhalb einer Playlist.
@Model
final class Channel {
    var id: UUID
    var name: String
    var streamURL: URL
    var logoURL: URL?
    /// `group-title` aus dem #EXTINF-Tag, z. B. "Sport", "News".
    var group: String?
    /// `tvg-id` aus dem #EXTINF-Tag. Wird (zusammen mit dem Namen) genutzt, um
    /// Favoriten über einen Refresh hinweg wiederzuerkennen.
    var tvgID: String?
    var isFavorite: Bool

    var playlist: Playlist?
    /// Denormalisierte ID der Playlist – ermöglicht schnelle, robuste
    /// `#Predicate`-Filter ohne optionales Relationship-Keypath-Traversal
    /// (wichtig bei sehr großen Playlists, z. B. 17k Xtream-Sender).
    var playlistID: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        streamURL: URL,
        logoURL: URL? = nil,
        group: String? = nil,
        tvgID: String? = nil,
        isFavorite: Bool = false,
        playlist: Playlist? = nil,
        playlistID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.logoURL = logoURL
        self.group = group
        self.tvgID = tvgID
        self.isFavorite = isFavorite
        self.playlist = playlist
        self.playlistID = playlistID
    }

    /// Schlüssel, über den ein Channel beim Refresh wiedererkannt wird:
    /// bevorzugt die `tvg-id`, sonst der (kleingeschriebene) Name.
    var favoriteKey: String {
        if let tvgID, !tvgID.isEmpty { return "id:\(tvgID)" }
        return "name:\(name.lowercased())"
    }
}
