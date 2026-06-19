import Foundation
import SwiftData

enum ImportError: LocalizedError {
    case invalidURL
    case emptyPlaylist
    case fileAccessDenied
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Die angegebene URL ist ungültig."
        case .emptyPlaylist: return "Die Playlist enthält keine gültigen Sender."
        case .fileAccessDenied: return "Auf die ausgewählte Datei kann nicht zugegriffen werden."
        case .network(let msg): return "Netzwerkfehler: \(msg)"
        }
    }
}

/// Lädt, parst und persistiert Playlists. Hält den `ModelContext` und läuft
/// auf dem MainActor, da SwiftData-Objekte hier erzeugt/verändert werden.
@MainActor
@Observable
final class PlaylistImporter {
    private let modelContext: ModelContext
    private let parser = M3UParser()

    /// True, während ein Import/Refresh läuft (für UI-Spinner).
    var isWorking = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Import

    /// Importiert eine Playlist von einer Remote-URL.
    @discardableResult
    func importFromURL(_ urlString: String, name: String) async throws -> Playlist {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme != nil else {
            throw ImportError.invalidURL
        }
        isWorking = true
        defer { isWorking = false }

        let text = try await fetchText(from: url)
        let parsed = parser.parse(text)
        guard !parsed.isEmpty else { throw ImportError.emptyPlaylist }

        let displayName = name.isEmpty ? (url.host ?? "Playlist") : name
        let playlist = Playlist(name: displayName, sourceURL: url, lastRefreshed: Date())
        modelContext.insert(playlist)
        attach(parsed, to: playlist, preservedFavorites: [])
        try modelContext.save()
        return playlist
    }

    /// Importiert eine Playlist über die Xtream-Codes-API (player_api.php).
    @discardableResult
    func importFromXtream(
        _ credentials: XtreamCredentials,
        output: XtreamOutput,
        name: String
    ) async throws -> Playlist {
        isWorking = true
        defer { isWorking = false }

        let client = XtreamClient(credentials: credentials)
        let parsed = try await client.fetchLiveChannels(output: output)
        guard !parsed.isEmpty else { throw ImportError.emptyPlaylist }

        let displayName = name.isEmpty ? (credentials.baseURL()?.host ?? "Xtream") : name
        let playlist = Playlist(
            name: displayName,
            sourceURL: credentials.playerAPIURL(),
            lastRefreshed: Date(),
            isXtream: true,
            xtreamOutput: output.rawValue
        )
        modelContext.insert(playlist)
        attach(parsed, to: playlist, preservedFavorites: [])
        try modelContext.save()
        return playlist
    }

    /// Importiert eine Playlist aus einer lokalen Datei (.m3u/.m3u8).
    /// Erwartet eine über `fileImporter` erhaltene, ggf. security-scoped URL.
    @discardableResult
    func importFromFile(_ fileURL: URL, name: String? = nil) async throws -> Playlist {
        isWorking = true
        defer { isWorking = false }

        let needsScope = fileURL.startAccessingSecurityScopedResource()
        defer { if needsScope { fileURL.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw ImportError.fileAccessDenied
        }
        let text = decodeText(data)
        let parsed = parser.parse(text)
        guard !parsed.isEmpty else { throw ImportError.emptyPlaylist }

        let displayName = name ?? fileURL.deletingPathExtension().lastPathComponent
        // Lokale Datei: sourceURL bleibt nil -> nicht refreshbar.
        let playlist = Playlist(name: displayName)
        modelContext.insert(playlist)
        attach(parsed, to: playlist, preservedFavorites: [])
        try modelContext.save()
        return playlist
    }

    // MARK: - Refresh

    /// Lädt eine Remote-Playlist neu. Favoriten werden über `favoriteKey`
    /// (tvg-id bzw. Name) erhalten. Unterstützt M3U-URL- und Xtream-Playlists.
    func refresh(_ playlist: Playlist) async throws {
        guard let url = playlist.sourceURL else { return }
        isWorking = true
        defer { isWorking = false }

        let parsed: [ParsedChannel]
        if playlist.isXtream, let creds = XtreamCredentials(playerAPIURL: url) {
            let output = XtreamOutput(rawValue: playlist.xtreamOutput ?? "") ?? .hls
            parsed = try await XtreamClient(credentials: creds).fetchLiveChannels(output: output)
        } else {
            let text = try await fetchText(from: url)
            parsed = parser.parse(text)
        }
        guard !parsed.isEmpty else { throw ImportError.emptyPlaylist }

        // Alte Favoriten-Schlüssel merken …
        let preserved = Set(playlist.channels.filter(\.isFavorite).map(\.favoriteKey))

        // … alte Channels entfernen (cascade kümmert sich beim Delete) …
        for old in playlist.channels {
            modelContext.delete(old)
        }
        playlist.channels.removeAll()

        // … und neu aufbauen, Favoriten dabei wiederherstellen.
        attach(parsed, to: playlist, preservedFavorites: preserved)
        playlist.lastRefreshed = Date()
        try modelContext.save()
    }

    // MARK: - Helpers

    /// Erzeugt Channel-Objekte und hängt sie an die Playlist. Setzt `isFavorite`
    /// für Channels, deren Schlüssel in `preservedFavorites` enthalten ist.
    private func attach(
        _ parsed: [ParsedChannel],
        to playlist: Playlist,
        preservedFavorites: Set<String>
    ) {
        for p in parsed {
            let channel = Channel(
                name: p.name,
                streamURL: p.streamURL,
                logoURL: p.logoURL,
                group: p.group,
                tvgID: p.tvgID,
                playlist: playlist,
                playlistID: playlist.id
            )
            channel.isFavorite = preservedFavorites.contains(channel.favoriteKey)
            modelContext.insert(channel)
            playlist.channels.append(channel)
        }
        // channels wurde gerade in-memory befüllt -> count ist hier günstig.
        playlist.channelCount = playlist.channels.count
    }

    private func fetchText(from url: URL) async throws -> String {
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw ImportError.network("HTTP \(http.statusCode)")
            }
            return decodeText(data)
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.network(error.localizedDescription)
        }
    }

    /// Dekodiert Playlist-Bytes; UTF-8 mit Latin-1-Fallback.
    private func decodeText(_ data: Data) -> String {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }
}
