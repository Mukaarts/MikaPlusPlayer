import SwiftUI
import SwiftData

/// Wurzel-Ansicht: TabView mit zwei Tabs, jeder mit eigenem NavigationStack.
struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                PlaylistsView()
            }
            .tabItem {
                Label("Playlists", systemImage: "list.and.film")
            }

            NavigationStack {
                FavoritesView()
            }
            .tabItem {
                Label("Favoriten", systemImage: "star.fill")
            }
        }
        .tint(.playerAccent)
        #if os(iOS)
        .toolbarBackground(.visible, for: .tabBar)
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Playlist.self, Channel.self], inMemory: true)
}
