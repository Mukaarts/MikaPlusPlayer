import SwiftUI

#if os(macOS)

/// Multiview-Fenster: mehrere Streams gleichzeitig, umschaltbar zwischen Fokus-Layout
/// (ein großer Haupt-Player + kleine Kacheln oben rechts, „wie bei Reacts") und Raster.
/// Das native Fenster-Vollbild (grüner Button / Menü „Vollbild") funktioniert hier
/// out of the box, weil es ein eigenständiges Fenster ist.
struct MultiviewScreen: View {
    @Environment(MultiviewSession.self) private var session

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if session.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Multiview")
        .toolbar {
            ToolbarItem(placement: .principal) { layoutPicker }
        }
        // Beim Schließen des Fensters alle Engines stoppen, sonst läuft Audio weiter.
        .onDisappear { session.clear() }
    }

    @ViewBuilder
    private var content: some View {
        switch session.layout {
        case .focus: focusLayout
        case .grid:  gridLayout
        }
    }

    // MARK: - Fokus-Layout (PiP)

    private var focusLayout: some View {
        let focused = session.slots[session.focusedIndex]
        return MultiviewTile(
            slot: focused,
            isFocused: true,
            onFocus: {},
            onClose: { session.remove(focused.id) }
        )
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 8) {
                ForEach(Array(session.slots.enumerated()), id: \.element.id) { index, slot in
                    if index != session.focusedIndex {
                        MultiviewTile(
                            slot: slot,
                            isFocused: false,
                            onFocus: { session.setFocus(index) },
                            onClose: { session.remove(slot.id) }
                        )
                        .frame(width: 240, height: 135)
                        .clipShape(RoundedRectangle(cornerRadius: PlayerTheme.cardRadius))
                        .shadow(radius: 8)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Raster-Layout

    private var gridLayout: some View {
        let count = session.slots.count
        let columns = count <= 1 ? 1 : 2
        let rows = (count + columns - 1) / columns
        return Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        if index < count {
                            let slot = session.slots[index]
                            MultiviewTile(
                                slot: slot,
                                isFocused: index == session.focusedIndex,
                                onFocus: { session.setFocus(index) },
                                onClose: { session.remove(slot.id) }
                            )
                        } else {
                            Color.clear
                        }
                    }
                }
            }
        }
    }

    // MARK: - Leerer Zustand & Toolbar

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Kein Stream im Multiview", systemImage: "rectangle.split.2x2")
        } description: {
            Text("Füge in der Senderliste mit dem ⊞-Button Sender hinzu, um sie hier gleichzeitig zu sehen.")
        }
    }

    private var layoutPicker: some View {
        Picker("Layout", selection: Binding(
            get: { session.layout },
            set: { session.layout = $0 }
        )) {
            ForEach(MultiviewLayout.allCases) { layout in
                Text(layout.label).tag(layout)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .disabled(session.slots.count < 2)
    }
}

#endif
