import SwiftUI

#if os(macOS)

/// Eine Kachel im Multiview: zeigt den Stream einer Engine mit Lade-/Fehler-Overlay,
/// einem Ton-Badge (welcher Stream gerade Ton hat) und einem Schließen-Button.
/// Ein Klick auf eine nicht fokussierte Kachel macht sie zum Haupt-/Ton-Stream.
struct MultiviewTile: View {
    let slot: MultiviewSession.Slot
    let isFocused: Bool
    let onFocus: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black
            slot.engine.makePlayerView()
                // Nicht-fokussierte Kacheln fangen keine Klicks ab, damit der
                // Fokus-Tap zuverlässig greift (AVKit-VideoPlayer hätte sonst eigene
                // Controls darüber). Der fokussierte Player behält seine Controls.
                .allowsHitTesting(isFocused)
            stateOverlay
            chrome
        }
        .overlay {
            RoundedRectangle(cornerRadius: PlayerTheme.cardRadius)
                .strokeBorder(isFocused ? Color.playerAccent : .clear, lineWidth: 2)
        }
        .contentShape(Rectangle())
        .onTapGesture { if !isFocused { onFocus() } }
    }

    /// Ladeanzeige bzw. Fehler-Fallback – analog zu `PlayerView.stateOverlay`.
    @ViewBuilder
    private var stateOverlay: some View {
        switch slot.engine.state {
        case .loading, .idle:
            ProgressView()
                .controlSize(.large)
                .tint(.white)
        case .failed(let message):
            ContentUnavailableView {
                Label("Wiedergabe fehlgeschlagen", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
            .background(.ultraThinMaterial)
        case .playing:
            EmptyView()
        }
    }

    /// Obere Leiste: Ton-Status + Sendername links, Schließen-Button rechts.
    private var chrome: some View {
        VStack {
            HStack(alignment: .top, spacing: 8) {
                PlayerBadge(
                    systemImage: isFocused ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    text: slot.channel.name,
                    tinted: isFocused
                )
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Stream entfernen")
            }
            Spacer()
        }
        .padding(8)
    }
}

#endif
