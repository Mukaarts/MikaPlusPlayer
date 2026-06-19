import Foundation

/// Holt Live-Sender direkt über die Xtream-Codes **player_api.php** und baut
/// daraus `ParsedChannel`-DTOs. Wird genutzt, weil viele Panels den klassischen
/// `get.php`-M3U-Link blockieren (HTTP 885 hinter Cloudflare), die player_api
/// aber bedienen.
struct XtreamClient {
    let credentials: XtreamCredentials

    enum XtreamError: LocalizedError {
        case invalidHost
        case auth
        case network(String)

        var errorDescription: String? {
            switch self {
            case .invalidHost: return "Host ungültig. Bitte prüfe die Eingabe."
            case .auth: return "Anmeldung fehlgeschlagen. Benutzername/Passwort prüfen."
            case .network(let m): return "Netzwerkfehler: \(m)"
            }
        }
    }

    /// Lädt Kategorien + Live-Streams und liefert fertige Channel-DTOs.
    func fetchLiveChannels(output: XtreamOutput) async throws -> [ParsedChannel] {
        guard let base = credentials.baseURL() else { throw XtreamError.invalidHost }
        let user = credentials.username.trimmingCharacters(in: .whitespaces)
        let pass = credentials.password.trimmingCharacters(in: .whitespaces)

        // 1) Auth prüfen.
        let auth: AuthResponse = try await get(base: base, action: nil)
        guard auth.userInfo?.auth == 1 else { throw XtreamError.auth }

        // 2) Kategorien (id -> Name) für group-title.
        let categories: [Category] = try await get(base: base, action: "get_live_categories")
        let groupByID = Dictionary(
            categories.map { ($0.categoryId, $0.categoryName) },
            uniquingKeysWith: { first, _ in first }
        )

        // 3) Live-Streams -> ParsedChannel.
        let streams: [Stream] = try await get(base: base, action: "get_live_streams")
        let ext = output.streamExtension

        return streams.compactMap { stream in
            let urlString = "\(base.absoluteString)/live/\(user)/\(pass)/\(stream.streamId.value).\(ext)"
            guard let url = URL(string: urlString) else { return nil }
            let tvg = stream.epgChannelId.flatMap { $0.isEmpty ? nil : $0 }
            return ParsedChannel(
                name: stream.name,
                streamURL: url,
                logoURL: stream.streamIcon.flatMap { $0.isEmpty ? nil : URL(string: $0) },
                group: stream.categoryId.flatMap { groupByID[$0] },
                tvgID: tvg
            )
        }
    }

    // MARK: - HTTP

    private func get<T: Decodable>(base: URL, action: String?) async throws -> T {
        guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw XtreamError.invalidHost
        }
        comps.path = "/player_api.php"
        var items = [
            URLQueryItem(name: "username", value: credentials.username.trimmingCharacters(in: .whitespaces)),
            URLQueryItem(name: "password", value: credentials.password.trimmingCharacters(in: .whitespaces))
        ]
        if let action { items.append(URLQueryItem(name: "action", value: action)) }
        comps.queryItems = items
        guard let url = comps.url else { throw XtreamError.invalidHost }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 60
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw XtreamError.network("HTTP \(http.statusCode)")
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as XtreamError {
            throw error
        } catch let error as DecodingError {
            throw XtreamError.network("Unerwartete Serverantwort (\(error.localizedDescription))")
        } catch {
            throw XtreamError.network(error.localizedDescription)
        }
    }

    // MARK: - DTOs (player_api.php)

    private struct AuthResponse: Decodable {
        let userInfo: UserInfo?
        enum CodingKeys: String, CodingKey { case userInfo = "user_info" }
        struct UserInfo: Decodable {
            let auth: Int?
        }
    }

    private struct Category: Decodable {
        let categoryId: String
        let categoryName: String
        enum CodingKeys: String, CodingKey {
            case categoryId = "category_id"
            case categoryName = "category_name"
        }
    }

    private struct Stream: Decodable {
        let name: String
        let streamId: FlexibleID
        let streamIcon: String?
        let epgChannelId: String?
        let categoryId: String?
        enum CodingKeys: String, CodingKey {
            case name
            case streamId = "stream_id"
            case streamIcon = "stream_icon"
            case epgChannelId = "epg_channel_id"
            case categoryId = "category_id"
        }
    }

    /// `stream_id`/`category_id` kommen je nach Panel als Int ODER String.
    private struct FlexibleID: Decodable {
        let value: String
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let i = try? c.decode(Int.self) { value = String(i) }
            else { value = try c.decode(String.self) }
        }
    }
}
