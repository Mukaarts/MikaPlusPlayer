import Foundation

/// Ausgabeformat einer Xtream-Codes-Playlist. Bestimmt die Datei-Endung der
/// Stream-URLs in der M3U und damit die nötige Wiedergabe-Engine.
enum XtreamOutput: String, CaseIterable, Identifiable {
    /// HLS (.m3u8) – spielt mit dem eingebauten AVKit-Player.
    case hls = "hls"
    /// Roher MPEG-TS (.ts) – benötigt VLCKit (siehe README).
    case mpegts = "mpegts"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hls: return "HLS (.m3u8)"
        case .mpegts: return "MPEG-TS (.ts)"
        }
    }

    var hint: String {
        switch self {
        case .hls: return "Spielt direkt mit AVKit – kein VLCKit nötig."
        case .mpegts: return "Originalformat des Anbieters – benötigt VLCKit."
        }
    }

    /// Datei-Endung der Live-Stream-URL (`/live/user/pass/<id>.<ext>`).
    var streamExtension: String {
        switch self {
        case .hls: return "m3u8"
        case .mpegts: return "ts"
        }
    }
}

/// Xtream-Codes-Zugangsdaten. Baut daraus die player_api-/get.php-Links.
struct XtreamCredentials {
    var host: String
    var username: String
    var password: String

    init(host: String, username: String, password: String) {
        self.host = host
        self.username = username
        self.password = password
    }

    /// Rekonstruiert die Zugangsdaten aus einer gespeicherten player_api-URL
    /// (`http://host[:port]/player_api.php?username=…&password=…`).
    init?(playerAPIURL url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = comps.host else { return nil }
        let items = comps.queryItems ?? []
        guard let user = items.first(where: { $0.name == "username" })?.value,
              let pass = items.first(where: { $0.name == "password" })?.value else { return nil }
        let scheme = comps.scheme ?? "http"
        let portPart = comps.port.map { ":\($0)" } ?? ""
        self.host = "\(scheme)://\(host)\(portPart)"
        self.username = user
        self.password = pass
    }

    /// Normalisierte Basis-URL (`http://host[:port]`), ohne Pfad/Query.
    /// Erzwingt `http://` (kein `https`), da viele IPTV-Panels nur HTTP bedienen.
    func baseURL() -> URL? {
        var h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !h.isEmpty else { return nil }

        let lower = h.lowercased()
        if lower.hasPrefix("https://") {
            h = "http://" + h.dropFirst("https://".count)
        } else if !lower.hasPrefix("http://") {
            h = "http://" + h
        }
        while h.hasSuffix("/") { h.removeLast() }

        guard var comps = URLComponents(string: h), comps.host != nil else { return nil }
        comps.path = ""
        comps.query = nil
        return comps.url
    }

    /// player_api.php-Basis-URL inkl. Zugangsdaten (dient auch als gespeicherte
    /// `sourceURL` einer Xtream-Playlist, aus der ein Refresh die Daten rekonstruiert).
    func playerAPIURL() -> URL? {
        guard var comps = baseURL().flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else {
            return nil
        }
        comps.path = "/player_api.php"
        comps.queryItems = [
            URLQueryItem(name: "username", value: username.trimmingCharacters(in: .whitespaces)),
            URLQueryItem(name: "password", value: password.trimmingCharacters(in: .whitespaces))
        ]
        return comps.url
    }

    /// Erzeugt den `get.php`-Playlist-Link für das gewählte Ausgabeformat.
    /// Hinweis: Manche Panels (z. B. hinter Cloudflare) blockieren `get.php` –
    /// dann wird stattdessen die player_api genutzt (siehe `XtreamClient`).
    func playlistURL(output: XtreamOutput) -> URL? {
        guard var comps = baseURL().flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else {
            return nil
        }
        comps.path = "/get.php"
        comps.queryItems = [
            URLQueryItem(name: "username", value: username.trimmingCharacters(in: .whitespaces)),
            URLQueryItem(name: "password", value: password.trimmingCharacters(in: .whitespaces)),
            URLQueryItem(name: "type", value: "m3u_plus"),
            URLQueryItem(name: "output", value: output.rawValue)
        ]
        return comps.url
    }

    var isComplete: Bool {
        ![host, username, password].contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
