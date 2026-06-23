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
    /// Geteilte Multiview-Session (nur macOS): erreicht Haupt- und Multiview-Fenster.
    @State private var multiview = MultiviewSession()
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
            #if os(macOS)
                .environment(multiview)
            #endif
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

        // Eigenständiges Multiview-Fenster (mehrere Streams gleichzeitig).
        // Dieselbe `multiview`-Instanz wie das Hauptfenster – so wirken die
        // „⊞"-Buttons der Senderliste live auf dieses Fenster.
        #if os(macOS)
        Window("Multiview", id: "multiview") {
            MultiviewScreen()
                .environment(multiview)
        }
        .modelContainer(modelContainer)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 720)
        #endif
    }
}
