import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Sheet zum Importieren einer Playlist per Xtream-Codes-Login, URL oder
/// lokaler Datei.
struct ImportPlaylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private enum Source: String, CaseIterable, Identifiable {
        case xtream = "Xtream"
        case url = "URL"
        case file = "Datei"
        var id: String { rawValue }
    }

    @State private var source: Source = .xtream
    @State private var urlString = ""
    @State private var name = ""
    @State private var isImporting = false
    @State private var showingFileImporter = false
    @State private var errorMessage: String?

    // Xtream-Codes-Felder
    @State private var xtreamHost = ""
    @State private var xtreamUser = ""
    @State private var xtreamPassword = ""
    // MPEG-TS als Standard: viele Panels (z. B. Telecasty) blockieren den
    // HLS-Endpunkt (HTTP 407) und liefern nur rohes .ts (-> VLCKit nötig).
    @State private var xtreamOutput: XtreamOutput = .mpegts

    /// Erlaubte Dateitypen für den fileImporter (.m3u/.m3u8).
    private var allowedTypes: [UTType] {
        var types: [UTType] = []
        if let m3u = UTType(filenameExtension: "m3u") { types.append(m3u) }
        if let m3u8 = UTType(filenameExtension: "m3u8") { types.append(m3u8) }
        types.append(.plainText)
        return types
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Quelle", selection: $source) {
                    ForEach(Source.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Section("Name (optional)") {
                    TextField("z. B. Mein IPTV-Anbieter", text: $name)
                }

                switch source {
                case .xtream:
                    Section("Xtream-Codes-Zugang") {
                        TextField("Host (z. B. http://dein-anbieter.tld)", text: $xtreamHost)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                            .autocorrectionDisabled()
                        TextField("Benutzername", text: $xtreamUser)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                        SecureField("Passwort", text: $xtreamPassword)
                    }
                    Section {
                        Picker("Format", selection: $xtreamOutput) {
                            ForEach(XtreamOutput.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Stream-Format")
                    } footer: {
                        Text(xtreamOutput.hint)
                    }
                    Section {
                        Button {
                            Task { await importFromXtream() }
                        } label: {
                            Label("Anmelden & importieren", systemImage: "person.badge.key")
                        }
                        .disabled(!xtreamCredentials.isComplete || isImporting)
                    }
                case .url:
                    Section("Playlist-URL") {
                        TextField("https://… .m3u8", text: $urlString)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                            .autocorrectionDisabled()
                        Button {
                            Task { await importFromURL() }
                        } label: {
                            Label("Von URL importieren", systemImage: "arrow.down.circle")
                        }
                        .disabled(urlString.isEmpty || isImporting)
                    }
                case .file:
                    Section("Lokale Datei") {
                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("Datei auswählen (.m3u/.m3u8)", systemImage: "folder")
                        }
                        .disabled(isImporting)
                    }
                }

                if isImporting {
                    HStack {
                        ProgressView()
                        Text("Importiere…").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Playlist importieren")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: allowedTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileResult(result)
            }
            .alert("Fehler", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .tint(.playerAccent)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }

    // MARK: - Aktionen

    private var xtreamCredentials: XtreamCredentials {
        XtreamCredentials(host: xtreamHost, username: xtreamUser, password: xtreamPassword)
    }

    private func importFromXtream() async {
        guard xtreamCredentials.isComplete else {
            errorMessage = "Bitte Host, Benutzername und Passwort ausfüllen."
            return
        }
        isImporting = true
        defer { isImporting = false }
        let importer = PlaylistImporter(modelContext: modelContext)
        do {
            try await importer.importFromXtream(xtreamCredentials, output: xtreamOutput, name: name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importFromURL() async {
        isImporting = true
        defer { isImporting = false }
        let importer = PlaylistImporter(modelContext: modelContext)
        do {
            try await importer.importFromURL(urlString, name: name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleFileResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await importFromFile(url) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func importFromFile(_ url: URL) async {
        isImporting = true
        defer { isImporting = false }
        let importer = PlaylistImporter(modelContext: modelContext)
        do {
            try await importer.importFromFile(url, name: name.isEmpty ? nil : name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
