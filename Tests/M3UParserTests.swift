import XCTest
@testable import MikaPlusPlayer

final class M3UParserTests: XCTestCase {
    private let parser = M3UParser()

    /// Komma im Anzeigenamen UND im group-title (innerhalb der Quotes) – der
    /// Name darf nur am ersten Komma AUSSERHALB der Quotes abgetrennt werden.
    func testQuoteSafeNameWithCommas() {
        let m3u = """
        #EXTM3U
        #EXTINF:-1 tvg-id="ard.de" tvg-logo="http://x/logo.png" group-title="News, Politik",Das Erste, HD
        http://example.com/stream.m3u8
        """
        let result = parser.parse(m3u)
        XCTAssertEqual(result.count, 1)
        let ch = result[0]
        XCTAssertEqual(ch.name, "Das Erste, HD")
        XCTAssertEqual(ch.tvgID, "ard.de")
        XCTAssertEqual(ch.group, "News, Politik")
        XCTAssertEqual(ch.logoURL?.absoluteString, "http://x/logo.png")
        XCTAssertEqual(ch.streamURL.absoluteString, "http://example.com/stream.m3u8")
    }

    /// Eintrag ohne Attribute: Name = alles nach dem ersten Komma.
    func testMinimalEntry() {
        let m3u = """
        #EXTINF:-1,Plain Channel
        http://example.com/a.ts
        """
        let result = parser.parse(m3u)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Plain Channel")
        XCTAssertNil(result[0].group)
        XCTAssertNil(result[0].tvgID)
    }

    /// Ungültige/leere URL-Zeilen werden übersprungen.
    func testSkipsInvalidURL() {
        let m3u = """
        #EXTINF:-1,Kaputt
        not a url
        #EXTINF:-1,Gut
        http://example.com/ok.m3u8
        """
        let result = parser.parse(m3u)
        XCTAssertEqual(result.map(\.name), ["Gut"])
    }

    /// #EXTGRP reicht eine Gruppe nach, wenn group-title fehlt.
    func testExtGrpFallback() {
        let m3u = """
        #EXTINF:-1,Sender X
        #EXTGRP:Sport
        http://example.com/x.m3u8
        """
        let result = parser.parse(m3u)
        XCTAssertEqual(result.first?.group, "Sport")
    }
}
