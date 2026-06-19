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

    var body: some View {
        ZStack {
            Color.black

            if let engine {
                engine.makePlayerView()
                stateOverlay(engine)
                controlsOverlay
            } else {
                ProgressView().tint(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleControls() }
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
        }
        .onDisappear {
            autoHideTask?.cancel()
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
            }
            .transition(.opacity)
        }
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
