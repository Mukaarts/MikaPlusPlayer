import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Wiedergabe-Ansicht. Wählt über die `PlaybackEngineFactory` die passende
/// Engine (AVKit für HLS, VLCKit für rohe TS-Streams) und zeigt je nach
/// Status Player, Ladeanzeige oder einen Fehler-Fallback. Unterstützt Vollbild.
struct PlayerView: View {
    let channel: Channel

    /// Die aktuell verwendete Engine. Über `any PlaybackEngine` typisiert,
    /// damit der View engine-unabhängig bleibt.
    @State private var engine: (any PlaybackEngine)?
    @State private var isFullscreen = false
    @State private var showControls = true
    @State private var autoHideTask: Task<Void, Never>?
    /// macOS: true, wenn der Mauszeiger nahe dem oberen Rand schwebt.
    @State private var topHover = false
    /// Fokus für die Tastatur-Steuerung (Leertaste, M, ↑/↓ usw.).
    @FocusState private var keyboardFocused: Bool
    /// Kurzzeitig eingeblendetes Feedback (HUD) bei Tastatur-/Button-Aktionen.
    @State private var hud: HUDKind?
    @State private var hudTask: Task<Void, Never>?

    /// Schrittweite der Lautstärke-Tasten (5 %).
    private let volumeStep = 0.05

    /// Art des HUD-Feedbacks.
    private enum HUDKind: Equatable {
        case playPause(Bool)   // isPaused
        case mute(Bool)        // isMuted
        case volume(Double)    // 0…1
    }

    var body: some View {
        ZStack {
            Color.black

            if let engine {
                engine.makePlayerView()
                stateOverlay(engine)
                controlsOverlay
                hudOverlay
            } else {
                ProgressView().tint(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleControls() }
        .focusable()
        .focusEffectDisabled()
        .focused($keyboardFocused)
        .onKeyPress { handleKey($0) }
        #if os(macOS)
        .onContinuousHover { handleHover($0) }
        #endif
        .ignoresSafeArea(edges: isFullscreen ? .all : [])
        .navigationTitle(isFullscreen ? "" : channel.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
        .toolbar(isFullscreen ? .hidden : .visible, for: .tabBar)
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        #elseif os(macOS)
        // Obere Fenster-Toolbar/Titelleiste im Vollbild ausblenden – erscheint
        // wieder, sobald der Mauszeiger nahe den oberen Rand kommt.
        .toolbar(macToolbarVisibility, for: .windowToolbar)
        #endif
        .onAppear {
            startIfNeeded()
            scheduleAutoHide()
            keyboardFocused = true
        }
        .onDisappear {
            autoHideTask?.cancel()
            hudTask?.cancel()
            resetOrientation()
            engine?.pause()
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private func stateOverlay(_ engine: any PlaybackEngine) -> some View {
        switch engine.state {
        case .loading, .idle:
            ProgressView()
                .controlSize(.large)
                .tint(.white)
        case .failed(let message):
            failureView(message)
        case .playing:
            EmptyView()
        }
    }

    /// Steuerungs-Overlay mit Vollbild-Umschalter (per Tap bzw. Hover sichtbar).
    @ViewBuilder
    private var controlsOverlay: some View {
        if controlsVisible, case .playing = engine?.state {
            VStack {
                HStack {
                    Spacer()
                    Button(action: toggleFullscreen) {
                        Image(systemName: isFullscreen
                              ? "arrow.down.right.and.arrow.up.left"
                              : "arrow.up.left.and.arrow.down.right")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(isFullscreen ? 24 : 12)
                }
                Spacer()
                bottomControls
            }
            .transition(.opacity)
        }
    }

    /// Untere Leiste: Play/Pause und Stumm (Tastatur-Pendants: Leertaste / M).
    @ViewBuilder
    private var bottomControls: some View {
        HStack(spacing: 20) {
            Button(action: togglePlay) {
                controlIcon(engine?.isPaused == true ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.plain)
            Button(action: toggleMute) {
                controlIcon(engine?.isMuted == true ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(isFullscreen ? 24 : 12)
    }

    private func controlIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .padding(12)
            .background(.black.opacity(0.5), in: Circle())
    }

    /// Zentrales, kurz eingeblendetes Feedback bei Tastatur-/Button-Aktionen.
    @ViewBuilder
    private var hudOverlay: some View {
        if let hud {
            Group {
                switch hud {
                case .playPause(let paused):
                    Image(systemName: paused ? "pause.fill" : "play.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                case .mute(let muted):
                    Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                case .volume(let value):
                    volumeHUD(value)
                }
            }
            .padding(28)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func volumeHUD(_ value: Double) -> some View {
        VStack(spacing: 10) {
            Image(systemName: volumeSymbol(value))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            ProgressView(value: value)
                .progressViewStyle(.linear)
                .frame(width: 140)
                .tint(.playerAccent)
            Text("\(Int((value * 100).rounded())) %")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private func volumeSymbol(_ value: Double) -> String {
        if value <= 0 { return "speaker.slash.fill" }
        if value < 0.34 { return "speaker.wave.1.fill" }
        if value < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    @ViewBuilder
    private func failureView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Wiedergabe fehlgeschlagen", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
            if isRawTransportStream {
                Text("Hinweis: Rohe MPEG-TS-Streams (.ts) benötigen VLCKit – siehe README.")
                    .font(.footnote)
            }
        } actions: {
            Button("Erneut versuchen") {
                engine?.load(channel.streamURL)
            }
            .buttonStyle(.borderedProminent)
            .tint(.playerAccent)
        }
        .background(.ultraThinMaterial)
    }

    private var isRawTransportStream: Bool {
        StreamType(url: channel.streamURL) == .transportStream
    }

    // MARK: - Steuerung

    /// Ob die eigene Steuerung (Vollbild-Button) sichtbar ist.
    private var controlsVisible: Bool {
        #if os(macOS)
        return showControls || (isFullscreen && topHover)
        #else
        return showControls
        #endif
    }

    #if os(macOS)
    /// Sichtbarkeit der nativen Fenster-Toolbar: normal automatisch, im Vollbild
    /// nur beim Hover am oberen Rand.
    private var macToolbarVisibility: Visibility {
        guard isFullscreen else { return .automatic }
        return topHover ? .visible : .hidden
    }

    private func handleHover(_ phase: HoverPhase) {
        let near: Bool
        switch phase {
        case .active(let location): near = location.y < 90
        case .ended: near = false
        @unknown default: near = false
        }
        if near != topHover {
            withAnimation(.easeInOut(duration: 0.2)) { topHover = near }
        }
    }
    #endif

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
        if showControls { scheduleAutoHide() }
    }

    /// Blendet die Steuerung nach kurzer Inaktivität automatisch aus.
    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { showControls = false }
        }
    }

    private func toggleFullscreen() {
        withAnimation(.easeInOut(duration: 0.25)) { isFullscreen.toggle() }
        applyFullscreenSideEffects(isFullscreen)
        showControls = true
        scheduleAutoHide()
        // macOS: Beim nativen Fullscreen-Wechsel wechselt das Key-Window – Fokus halten.
        keyboardFocused = true
    }

    // MARK: - Tastatur & Aktionen

    /// Wertet einen Tastendruck aus. `.handled` unterdrückt u. a. den macOS-Systembeep.
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .space:
            togglePlay(); return .handled
        case .upArrow:
            changeVolume(volumeStep); return .handled
        case .downArrow:
            changeVolume(-volumeStep); return .handled
        case .escape:
            if isFullscreen { toggleFullscreen(); return .handled }
            return .ignored
        default:
            break
        }
        switch press.characters.lowercased() {
        case "m":
            toggleMute(); return .handled
        case "f":
            toggleFullscreen(); return .handled
        case "+", "=":
            changeVolume(volumeStep); return .handled
        case "-":
            changeVolume(-volumeStep); return .handled
        default:
            return .ignored
        }
    }

    private func togglePlay() {
        guard let engine else { return }
        engine.togglePlayPause()
        flashControls()
        showHUD(.playPause(engine.isPaused))
    }

    private func toggleMute() {
        guard let engine else { return }
        engine.toggleMute()
        flashControls()
        showHUD(.mute(engine.isMuted))
    }

    private func changeVolume(_ delta: Double) {
        guard let engine else { return }
        engine.setVolume(engine.volume + delta)
        showHUD(.volume(engine.volume))
    }

    /// Blendet die Steuerung kurz ein und startet den Auto-Hide neu.
    private func flashControls() {
        withAnimation(.easeInOut(duration: 0.2)) { showControls = true }
        scheduleAutoHide()
    }

    /// Zeigt das HUD-Feedback und blendet es nach kurzer Zeit wieder aus.
    private func showHUD(_ kind: HUDKind) {
        withAnimation(.easeInOut(duration: 0.15)) { hud = kind }
        hudTask?.cancel()
        hudTask = Task {
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { hud = nil }
        }
    }

    // MARK: - Plattform-spezifisches Vollbild

    private func applyFullscreenSideEffects(_ fullscreen: Bool) {
        #if os(iOS)
        // Auf dem iPhone Querformat anfordern (iPad/Info.plist erlauben Rotation ohnehin).
        guard UIDevice.current.userInterfaceIdiom == .phone,
              let scene = activeWindowScene else { return }
        let mask: UIInterfaceOrientationMask = fullscreen ? .landscapeRight : .portrait
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        #elseif os(macOS)
        // Natives Fenster-Vollbild umschalten, falls noch nicht im passenden Zustand.
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            let isWindowFullscreen = window.styleMask.contains(.fullScreen)
            if isWindowFullscreen != fullscreen { window.toggleFullScreen(nil) }
        }
        #endif
    }

    private func resetOrientation() {
        guard isFullscreen else { return }
        applyFullscreenSideEffects(false)
    }

    #if os(iOS)
    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
    #endif

    // MARK: - Wiedergabe

    private func startIfNeeded() {
        if engine == nil {
            let newEngine = PlaybackEngineFactory.engine(for: channel.streamURL)
            engine = newEngine
            newEngine.load(channel.streamURL)
        } else {
            engine?.play()
        }
    }
}
