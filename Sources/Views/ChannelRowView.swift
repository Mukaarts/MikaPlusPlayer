import SwiftUI
import SwiftData

/// Inhalt einer Sender-Card: Logo, Name, Gruppe und Favoriten-Stern.
/// Der Card-Rahmen wird vom Aufrufer via `.playerCard()` gesetzt.
struct ChannelRowView: View {
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @Environment(MultiviewSession.self) private var multiview
    @Environment(\.openWindow) private var openWindow
    #endif
    @Bindable var channel: Channel

    var body: some View {
        HStack(spacing: 12) {
            logo
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let group = channel.group, !group.isEmpty {
                    PlayerBadge(systemImage: nil, text: group)
                }
            }
            Spacer(minLength: 8)
            #if os(macOS)
            multiviewButton
            #endif
            favoriteButton
        }
    }

    @ViewBuilder
    private var logo: some View {
        AsyncImage(url: channel.logoURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit().padding(4)
            case .failure:
                placeholder
            case .empty:
                ProgressView()
            @unknown default:
                placeholder
            }
        }
        .frame(width: 48, height: 48)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholder: some View {
        Image(systemName: "tv")
            .font(.title3)
            .foregroundStyle(.secondary)
    }

    private var favoriteButton: some View {
        Button {
            channel.isFavorite.toggle()
            try? modelContext.save()
        } label: {
            Image(systemName: channel.isFavorite ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(channel.isFavorite ? Color.playerAccent : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    #if os(macOS)
    /// Fügt den Sender zum Multiview hinzu und öffnet das Multiview-Fenster.
    private var multiviewButton: some View {
        Button {
            multiview.add(channel)
            openWindow(id: "multiview")
        } label: {
            Image(systemName: "rectangle.split.2x2")
                .font(.title3)
                .foregroundStyle(multiview.canAddMore ? Color.secondary : Color.secondary.opacity(0.3))
        }
        .buttonStyle(.plain)
        .disabled(!multiview.canAddMore)
        .help(multiview.canAddMore ? "Zu Multiview hinzufügen" : "Multiview voll (max. 4)")
    }
    #endif
}
