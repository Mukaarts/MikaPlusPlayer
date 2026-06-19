import SwiftUI
import SwiftData

/// Übersicht aller importierten Playlists. Einstieg in den Import und in die
/// jeweilige Senderliste. Stil angelehnt an die Mika+ Familie.
struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Playlist.createdAt, order: .reverse) private var playlists: [Playlist]

    @State private var showingImport = false
    @State private var refreshingID: PersistentIdentifier?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PlayerTheme.sectionSpacing) {
                PlayerHeader(subline: "MIKA+ · PLAYLISTS", title: "Playlists") {
                    Button { showingImport = true } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.playerAccent)
                }

                if playlists.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: PlayerTheme.rowSpacing) {
                        ForEach(playlists) { playlist in
                            NavigationLink(value: playlist) {
                                PlaylistRow(
                                    playlist: playlist,
                                    isRefreshing: refreshingID == playlist.persistentModelID
                                )
                                .playerCard()
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if playlist.isRemote {
                                    Button {
                                        Task { await refresh(playlist) }
                                    } label: {
                                        Label("Aktualisieren", systemImage: "arrow.clockwise")
                                    }
                                }
                                Button(role: .destructive) {
                                    delete(playlist)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, PlayerTheme.contentHPadding)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color.playerBackground.ignoresSafeArea())
        .navigationTitle("Playlists")
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationDestination(for: Playlist.self) { playlist in
            ChannelListView(playlist: playlist)
        }
        .sheet(isPresented: $showingImport) {
            ImportPlaylistView()
        }
        .alert("Fehler", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.and.film")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Keine Playlists")
                .font(.headline)
            Text("Importiere eine M3U/M3U8-Playlist per URL oder Datei, um loszulegen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Playlist importieren") { showingImport = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.playerAccent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PlayerTheme.contentHPadding)
        .padding(.top, 60)
    }

    // MARK: - Aktionen

    private func delete(_ playlist: Playlist) {
        modelContext.delete(playlist)
        try? modelContext.save()
    }

    private func refresh(_ playlist: Playlist) async {
        refreshingID = playlist.persistentModelID
        defer { refreshingID = nil }
        let importer = PlaylistImporter(modelContext: modelContext)
        do {
            try await importer.refresh(playlist)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Eine Card-Zeile in der Playlist-Liste.
private struct PlaylistRow: View {
    let playlist: Playlist
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: playlist.isRemote ? "globe" : "doc")
                .font(.title3)
                .foregroundStyle(Color.playerAccent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PlayerBadge(systemImage: "tv", text: "\(playlist.channelCount) Sender")
            }
            Spacer()
            if isRefreshing {
                ProgressView()
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
