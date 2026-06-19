import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Zentrale Layout-Konstanten – analog zu den `…Theme`-Enums der übrigen
/// Mika+ Apps (gleiche Radien/Abstände für einheitliches Look & Feel).
enum PlayerTheme {
    static let cardRadius: CGFloat = 12
    static let cardVPadding: CGFloat = 14
    static let cardHPadding: CGFloat = 14
    static let cardBorderWidth: CGFloat = 1
    static let rowSpacing: CGFloat = 10
    static let sectionSpacing: CGFloat = 22
    static let contentHPadding: CGFloat = 20
}

// MARK: - Farben (adaptiv, Dark/Light – ohne Asset-Catalog)

extension Color {
    /// Akzentfarbe des Players: Rot wie das „Watch"-Modul der Mika+ Familie
    /// (semantisch passend zum Video-Schauen).
    static let playerAccent = Color(light: (239, 68, 68), dark: (248, 113, 113))

    /// App-Hintergrund (warmes Hell-Grau / fast Schwarz).
    static let playerBackground = Color(light: (246, 244, 243), dark: (18, 15, 16))

    /// Card-Hintergrund.
    static let playerCardBackground = Color(light: (255, 255, 255), dark: (32, 28, 29))

    /// Dünne Card-Border.
    static let playerCardBorder = Color(light: (230, 226, 224), dark: (56, 50, 52))

    /// Initialisiert eine adaptive Farbe aus 0–255-RGB für Light/Dark.
    init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
        #if os(iOS)
        self.init(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255, alpha: 1)
        })
        #elseif os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0 / 255, green: c.1 / 255, blue: c.2 / 255, alpha: 1)
        })
        #else
        let c = light
        self.init(.sRGB, red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255, opacity: 1)
        #endif
    }
}

// MARK: - Wiederverwendbare Komponenten

/// Card-Rahmen im Mika+ Stil: opaker Hintergrund + 1pt-Border, Radius 12.
struct PlayerCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, PlayerTheme.cardVPadding)
            .padding(.horizontal, PlayerTheme.cardHPadding)
            .background(
                Color.playerCardBackground,
                in: RoundedRectangle(cornerRadius: PlayerTheme.cardRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PlayerTheme.cardRadius)
                    .strokeBorder(Color.playerCardBorder, lineWidth: PlayerTheme.cardBorderWidth)
            }
    }
}

extension View {
    /// Versieht den Inhalt mit dem Mika+ Card-Look.
    func playerCard() -> some View { modifier(PlayerCardModifier()) }
}

/// Seiten-Header im Mika+ Stil: getrackte ALL-CAPS-Subline in Akzentfarbe
/// über einem großen, fetten Titel, optional mit Trailing-Aktionen.
struct PlayerHeader<Trailing: View>: View {
    let subline: String
    let title: String
    @ViewBuilder var trailing: Trailing

    init(subline: String, title: String, @ViewBuilder trailing: () -> Trailing) {
        self.subline = subline
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(subline)
                    .font(.caption2.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.playerAccent)
                Text(title)
                    .font(.largeTitle.bold())
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, PlayerTheme.contentHPadding)
    }
}

extension PlayerHeader where Trailing == EmptyView {
    init(subline: String, title: String) {
        self.init(subline: subline, title: title) { EmptyView() }
    }
}

/// Capsule-Badge (z. B. Sender-Anzahl, Gruppe) im Mika+ Stil.
struct PlayerBadge: View {
    let systemImage: String?
    let text: String
    var tinted: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.semibold))
            }
            Text(text).font(.caption.weight(.semibold)).monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(tinted ? Color.playerAccent : Color.secondary)
        .background(
            tinted ? Color.playerAccent.opacity(0.18) : Color.secondary.opacity(0.14),
            in: Capsule()
        )
    }
}
