import SwiftUI
import SwiftData

/// Favoriten-Tab: zeigt alle als Favorit markierten Sender über ALLE Playlists
/// hinweg. Der Filter läuft über das skalare `isFavorite`-Feld – zuverlässiger
/// als ein #Predicate über optionale Relationship-Keypaths.
struct FavoritesView: View {
    @Query(
        filter: #Predicate<Channel> { $0.isFavorite == true },
        sort: \Channel.name
    )
    private var favorites: [Channel]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PlayerTheme.sectionSpacing) {
                PlayerHeader(subline: "MIKA+ · FAVORITEN", title: "Favoriten")

                if favorites.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: PlayerTheme.rowSpacing) {
                        ForEach(favorites) { channel in
                            NavigationLink(value: channel) {
                                ChannelRowView(channel: channel).playerCard()
                            }
                            .buttonStyle(.plain)
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
        .navigationTitle("Favoriten")
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationDestination(for: Channel.self) { channel in
            PlayerView(channel: channel)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Keine Favoriten").font(.headline)
            Text("Markiere Sender mit dem Stern, um sie hier zu sammeln.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PlayerTheme.contentHPadding)
        .padding(.top, 60)
    }
}
