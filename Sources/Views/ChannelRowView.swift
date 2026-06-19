import SwiftUI
import SwiftData

/// Inhalt einer Sender-Card: Logo, Name, Gruppe und Favoriten-Stern.
/// Der Card-Rahmen wird vom Aufrufer via `.playerCard()` gesetzt.
struct ChannelRowView: View {
    @Environment(\.modelContext) private var modelContext
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
}
