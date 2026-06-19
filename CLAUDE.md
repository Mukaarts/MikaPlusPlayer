# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Was das ist

IPTV-Player in SwiftUI für **iOS 17+ und macOS 14+**, gemeinsames Codebase, SwiftData-Persistenz.
Import von M3U/M3U8-Playlists (URL/Datei) **und** Xtream-Codes-Login; Senderliste mit Suche/Gruppen-Filter/Favoriten;
Wiedergabe über eine austauschbare Engine (AVKit für HLS, VLCKit für rohe MPEG-TS). macOS wird per DMG + Sparkle-Updater verteilt.

## Projekt-Generierung (XcodeGen)

Es gibt **kein eingechecktes `.xcodeproj`** — es wird aus `project.yml` erzeugt. Nach jeder Änderung an `project.yml`
(Targets, Settings, Dependencies, Bundle-ID, Signing) **neu generieren**:

```sh
xcodegen generate          # erzeugt MikaPlusPlayer.xcodeproj
```

`xcodebuild` braucht das **vollständige Xcode**. Wenn `xcode-select -p` auf CommandLineTools zeigt, jedem Befehl
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` voranstellen (kein sudo nötig).

## Build / Test

**Zwei Schemata** (iOS und macOS sind getrennte Targets, siehe Architektur):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# macOS (enthält Sparkle + Tests)
xcodebuild build -project MikaPlusPlayer.xcodeproj -scheme MikaPlusPlayer-macOS -destination 'platform=macOS'
xcodebuild test  -project MikaPlusPlayer.xcodeproj -scheme MikaPlusPlayer-macOS -destination 'platform=macOS'

# iOS
xcodebuild build -project MikaPlusPlayer.xcodeproj -scheme MikaPlusPlayer -destination 'generic/platform=iOS Simulator'
```

Einzelnen Test laufen lassen: `-only-testing:MikaPlusPlayerTests/M3UParserTests/testQuoteSafeNameWithCommas`.
Tests sind **macOS-only** (Target `MikaPlusPlayerTests`, gehostet von der Mac-App) und decken die reinen
Parser/URL-Builder ab (`M3UParserTests`, `XtreamCodesTests`).

Beim Verifizieren der Build-Ausgabe: nicht naiv nach `error`/`icon`/`simulator` grep'en — diese Wörter stecken in
DerivedData-Pfaden und überfluten die Ausgabe. Auf `^\*\* BUILD (SUCCEEDED|FAILED) \*\*` filtern.

## Release (macOS, DMG + Auto-Update)

```sh
bash scripts/release.sh    # Build (Release) -> dist/*.dmg -> signierter appcast.xml
```

Einzelschritte: `scripts/build-macos.sh`, `scripts/make-dmg.sh`. Der EdDSA-Privatkey zum Signieren der Updates liegt
in der **macOS-Keychain** (familienweit geteilt, Public Key in `Info.plist` als `SUPublicEDKey`). Danach GitHub-Release
anlegen, DMG hochladen, `appcast.xml` auf `main` pushen. Repo-Pfad/Feed in `Info.plist` (`SUFeedURL`) und
`scripts/release.sh` (`GH_REPO`).

## Architektur (das Big Picture)

Saubere Trennung in `Sources/App | Models | Services | Views`. Ein gemeinsames Codebase, Plattform-Code via
`#if os(iOS)` / `#if os(macOS)`.

### Zwei Targets, ein Codebase — und warum
`project.yml` definiert **zwei App-Targets** (`MikaPlusPlayer` = iOS, `MikaPlusPlayer-macOS` = macOS), die sich
über ein `targetTemplate` (`AppBase`) **dasselbe `Sources/`** teilen; beide erzeugen `MikaPlusPlayer.app`.
Grund: **Sparkle ist macOS-only** und lässt sich in einem einzigen `supportedDestinations`-Target nicht sauber nur
für macOS linken (XcodeGen-Fallstrick: `platformFilter: macOS` → emittiert fälschlich `maccatalyst`; `platformFilters`
wird ignoriert). Deshalb hängt Sparkle nur am macOS-Target. Eine neue plattform-divergente Dependency gehört an das
jeweilige Target, **nicht** an das Template.

### Wiedergabe-Abstraktion (Kern der Erweiterbarkeit)
`Services/PlaybackEngine.swift` definiert das Protokoll `PlaybackEngine` (+ `PlaybackState`, `StreamType`) und die
`PlaybackEngineFactory`. Views sprechen **ausschließlich** `any PlaybackEngine` an. Die Factory wählt anhand der
URL-Endung: `.m3u8` → `AVKitPlaybackEngine`, `.ts`/`.mpegts` → `VLCPlaybackEngine` (falls VLCKit vorhanden), sonst
AVKit-Fallback. Eine neue Engine = Klasse + ein Eintrag in der Factory, kein anderer Code ändert sich.
**Wichtig:** AVPlayer kann **kein** rohes MPEG-TS — dafür ist VLCKit zwingend.

### VLCKit
SwiftPM-Binärpaket `tylerjonesio/vlckit-spm` (Import-Modul **`VLCKitSPM`**, nicht `VLCKit`/`MobileVLCKit`).
Der gesamte VLC-Code in `VLCPlaybackEngine.swift` steht hinter
`#if canImport(VLCKitSPM) || canImport(MobileVLCKit) || canImport(VLCKit)` — ohne das Paket baut die App weiter
(AVKit-Fallback). Beim Vollbild-/Player-Design beachten: VLC hat **eine einzige** Drawable-View — Vollbild ist daher
„in-place" gelöst (Chrome ausblenden), **keine** zweite Player-Instanz.

### Import-Pfade (`Services`)
- `M3UParser` — quote-sicherer #EXTINF-Parser; Anzeigename = Text nach dem **ersten Komma außerhalb von
  Anführungszeichen**. Liefert das DTO `ParsedChannel` (kontextfrei, testbar; **kein** `@Model`).
- `XtreamCodes` / `XtreamClient` — Xtream-Codes. Viele Panels **blockieren `get.php`/HLS**; daher baut `XtreamClient`
  die Senderliste über **`player_api.php`** (Kategorien + Live-Streams) und liefert ebenfalls `[ParsedChannel]`.
- `PlaylistImporter` (`@MainActor @Observable`) — einziger Ort, der `@Model`-Objekte erzeugt/speichert; hält den
  `ModelContext`. `refresh()` erhält Favoriten über `Channel.favoriteKey` (`tvgID ?? name`).

### SwiftData-Modelle & Performance
`Playlist` (cascade → `Channel`). Bewusste **Denormalisierungen** wegen sehr großer Playlists (Xtream liefert oft
>15k Sender): `Channel.playlistID` (für schnelle `#Predicate`-Filter ohne optionales Relationship-Traversal) und
`Playlist.channelCount` (Zählen ohne die ganze Relationship zu faulten). `ChannelListView` lädt Sender **DB-gestützt**
via dynamische `@Query` (Filter/Sortierung in der DB), nicht in-memory. Favoriten-Tab filtert über das skalare
`isFavorite`. Beide Werte beim Anlegen/Refresh mitführen (siehe `PlaylistImporter.attach`).

### UI-Stil (Mika+ Familie)
`Views/Theme/PlayerTheme.swift` ist die zentrale Quelle: Layout-Konstanten (`cardRadius` etc.), adaptive Farben
(programmatisch via UIColor/NSColor dynamicProvider, **kein** Asset-Catalog für Farben) und wiederverwendbare
Komponenten (`.playerCard()`, `PlayerHeader`, `PlayerBadge`). Akzentfarbe `Color.playerAccent`.

## Signing-Konventionen (kein Apple-Team nötig zum lokalen Laufen)
- **macOS**: Manual + `CODE_SIGN_IDENTITY = "-"` ("Sign to Run Locally"), Sandbox **deaktiviert** (DMG-Distribution
  + Sparkle), `disable-library-validation` an.
- **iOS**: Automatic mit `DEVELOPMENT_TEAM` in `project.yml` (aktuell `CWJM4J4HFN`); Gerät & Simulator signieren automatisch.
- Bundle-ID-Prefix `lu.daumedia`. ATS erlaubt HTTP (`NSAllowsArbitraryLoads`) für HTTP-Streams.

## Nützlicher Kontext
Persistente Notizen unter `~/.claude/projects/-Users-michaelferreira-ShiftProjects-MikaPlusPlayer/memory/`
(Anbieter-Setup Telecasty, Mika+ Design-Sprache, Sparkle/DMG-Details). Bei Verweisen auf Dateien/Flags vorher
prüfen, ob sie noch existieren.
