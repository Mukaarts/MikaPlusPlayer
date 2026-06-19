import SwiftUI
import SwiftData

/// Senderliste einer Playlist mit Suche und horizontalen Gruppen-Filter-Chips.
/// Die eigentliche Senderliste wird DB-gestützt (`@Query`) gefiltert/sortiert –
/// das bleibt auch bei sehr großen Playlists (z. B. 17k Xtream-Sender) flüssig.
struct ChannelListView: View {
    @Environment(\.modelContext) private var modelContext
    let playlist: Playlist

    @State private var searchText = ""
    @State private var selectedGroup: String?
    @State private var groups: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PlayerTheme.sectionSpacing) {
                PlayerHeader(
                    subline: "MIKA+ · \(playlist.channelCount) SENDER",
                    title: playlist.name
                )

                ChannelResultsList(
                    playlistID: playlist.id,
                    searchText: searchText,
                    group: selectedGroup
                )
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color.playerBackground.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { groupFilterBar }
        .navigationTitle(playlist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(for: Channel.self) { channel in
            PlayerView(channel: channel)
        }
        .searchable(text: $searchText, prompt: "Sender suchen")
        .task(id: playlist.id) { loadGroups() }
    }

    // MARK: - Gruppen-Filter

    @ViewBuilder
    private var groupFilterBar: some View {
        if groups.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    GroupChip(title: "Alle", isSelected: selectedGroup == nil) {
                        selectedGroup = nil
                    }
                    ForEach(groups, id: \.self) { group in
                        GroupChip(title: group, isSelected: selectedGroup == group) {
                            selectedGroup = (selectedGroup == group) ? nil : group
                        }
                    }
                }
                .padding(.horizontal, PlayerTheme.contentHPadding)
                .padding(.vertical, 10)
            }
            .background(.bar)
        }
    }

    /// Lädt die distinct-Gruppennamen einmalig (statt pro Render zu scannen).
    private func loadGroups() {
        let pid = playlist.id
        var descriptor = FetchDescriptor<Channel>(
            predicate: #Predicate { $0.playlistID == pid }
        )
        descriptor.propertiesToFetch = [\.group]
        let fetched = (try? modelContext.fetch(descriptor)) ?? []
        let names = fetched.compactMap { $0.group?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        groups = Array(Set(names)).sorted()
    }
}

/// DB-gestützte, gefilterte + sortierte Senderliste als Karten.
private struct ChannelResultsList: View {
    @Query private var channels: [Channel]
    private let searchText: String

    init(playlistID: UUID, searchText: String, group: String?) {
        self.searchText = searchText
        let s = searchText
        let g = group
        let predicate = #Predicate<Channel> { ch in
            ch.playlistID == playlistID
                && (s.isEmpty || ch.name.localizedStandardContains(s))
                && (g == nil || ch.group == g)
        }
        _channels = Query(filter: predicate, sort: [SortDescriptor(\.name, comparator: .localized)])
    }

    var body: some View {
        if channels.isEmpty {
            if searchText.isEmpty {
                emptyState
            } else {
                ContentUnavailableView.search(text: searchText)
                    .padding(.top, 40)
            }
        } else {
            LazyVStack(spacing: PlayerTheme.rowSpacing) {
                ForEach(channels) { channel in
                    NavigationLink(value: channel) {
                        ChannelRowView(channel: channel).playerCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PlayerTheme.contentHPadding)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tv.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Keine Sender").font(.headline)
            Text("Diese Playlist enthält keine Sender.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

/// Ein anklickbarer Filter-Chip im Mika+ Capsule-Stil.
private struct GroupChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(
                        isSelected ? Color.playerAccent : Color.secondary.opacity(0.16)
                    )
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
