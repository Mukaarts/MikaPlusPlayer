import SwiftUI
import SwiftData

@main
struct MikaPlusPlayerApp: App {
    /// Gemeinsamer SwiftData-Container für beide Plattformen.
    let modelContainer: ModelContainer = {
        let schema = Schema([Playlist.self, Channel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }()

    #if os(macOS)
    /// Sparkle-Auto-Updater (nur macOS).
    @State private var updater = SparkleUpdater()
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Nach Updates suchen …") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }
        #endif
    }
}
