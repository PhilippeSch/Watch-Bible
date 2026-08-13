import SwiftUI
import WatchKit

/// Aktiver Zustand des Themas. watchOS wertet Any/Dark-Varianten im Asset-
/// Katalog nicht aus und ignoriert auch \.colorScheme fuer benannte Farben
/// (im Simulator verifiziert) — deshalb je Rolle zwei Colorsets (…Day/…Night)
/// und dieser beobachtbare Schalter. Die Farbwerte selbst bleiben im Katalog.
@Observable
@MainActor
final class ThemeState {
    static let shared = ThemeState()
    var isNight = true
}

/// Farbrollen der Designspezifikation. Views lesen weiterhin Color.ground etc.;
/// die Aufloesung Tag/Nacht passiert hier zentral und ist beobachtbar.
@MainActor
extension Color {
    static var ground: Color       { ThemeState.shared.isNight ? Color("GroundNight")      : Color("GroundDay") }
    static var ink: Color          { ThemeState.shared.isNight ? Color("InkNight")         : Color("InkDay") }
    static var carmine: Color      { ThemeState.shared.isNight ? Color("CarmineNight")     : Color("CarmineDay") }
    static var brass: Color        { ThemeState.shared.isNight ? Color("BrassNight")       : Color("BrassDay") }
    static var secondaryInk: Color { ThemeState.shared.isNight ? Color("SecondaryNight")   : Color("SecondaryDay") }
    static var rule: Color         { ThemeState.shared.isNight ? Color("RuleNight")        : Color("RuleDay") }
    static var fieldFill: Color    { ThemeState.shared.isNight ? Color("FieldNight")       : Color("FieldDay") }
    static var ribbonTrack: Color  { ThemeState.shared.isNight ? Color("RibbonTrackNight") : Color("RibbonTrackDay") }
}

/// Typografie gemaess Designspezifikation, Kapitel 2. Verstext in der
/// Serifen-Variante; Bedienelemente und Zahlen serifenlos — der Bruch ist
/// beabsichtigt und entspricht dem Satz einer gedruckten Bibel.
enum Typo {
    static let reference   = Font.system(size: 11, weight: .semibold)
    static let gridDigit   = Font.system(size: 17, weight: .semibold).monospacedDigit()
    static let counter     = Font.system(size: 9, design: .monospaced)
    static let register    = Font.system(size: 9.5, weight: .bold)
    static let eyebrow     = Font.system(size: 9.5, weight: .bold)
    /// Abschnittstitel in Listen (z. B. Sprache in der Uebersetzungswahl) —
    /// groesser als der Eyebrow, damit er auf der Uhr gut lesbar bleibt.
    static let sectionHeader = Font.system(size: 13, weight: .semibold)
    static let bookRow     = Font.system(size: 15, weight: .semibold)
    static let bookCount   = Font.system(size: 10, design: .monospaced)
    static let tableRow    = Font.system(size: 10)
    static let homeRow     = Font.system(size: 15, weight: .semibold)

    /// Chinesische Schrift braucht mehr Flaeche und dichteren Zeilenfall;
    /// ein Serif-Parameter greift bei PingFang nicht (Designspez. 5a).
    static func verse(scale: AppSettings.TextScale, language: String) -> Font {
        if language.hasPrefix("zh") {
            return .system(size: scale.verseSize + 2)
        }
        return .system(size: scale.verseSize, design: .serif)
    }

    static func verseLineSpacing(scale: AppSettings.TextScale, language: String) -> CGFloat {
        let factor: CGFloat = language.hasPrefix("zh") ? 0.6 : 0.42
        return scale.verseSize * factor
    }

    static func verseNumber(scale: AppSettings.TextScale) -> Font {
        .system(size: scale.verseSize * 0.6, weight: .bold)
    }

    static func verseNumberOffset(scale: AppSettings.TextScale) -> CGFloat {
        scale.verseSize * 0.44
    }
}

/// Seitenraender (Designspezifikation, Kapitel 3).
enum Layout {
    /// Rand links und rechts fuer **Text ohne eigene Flaeche**: Listenzeilen,
    /// Impressum. 14 pt, wie es die Spezifikation vorgibt.
    ///
    /// Der Einstieg kommt auf denselben Wert, nur anders zusammengesetzt: dort
    /// liegt der Text auf einer Feldflaeche, die bei 2 pt beginnt und innen
    /// 12 pt Luft laesst. Rasterzellen tragen ihre Flaeche ebenfalls selbst und
    /// bleiben darum bei 2 pt — 14 pt ergaeben auf der 40-mm-Uhr 40.7 pt breite
    /// Zellen und unterschritten die 44 pt fuer Tippziele.
    static let textInset: CGFloat = 14
}

/// Rastergeometrie (Designspezifikation, Kapitel 3): immer drei Spalten —
/// vier ergaeben 38-pt-Zellen und unterschritten die 44 pt fuer Tippziele.
enum Grid3 {
    static let spacing: CGFloat = 6
    static let cellHeight: CGFloat = 52
    static let cornerRadius: CGFloat = 14
    static let columns = Array(repeating: GridItem(.flexible(), spacing: spacing),
                               count: 3)
}

/// Haelt ThemeState mit Einstellung, Uhrzeit und Handgelenk-Zustand synchron.
/// Bei `isLuminanceReduced` immer Nacht — helles Papier bei gesenktem
/// Handgelenk waere falsch, unabhaengig der Einstellung.
///
/// `\.colorScheme` faerbt zwar keine benannten Farben (siehe ThemeState),
/// steuert aber alles, was das System selbst zeichnet: den Wert eines Pickers
/// unter seiner Beschriftung, Warnhinweise, `.secondary`. Ohne das steht im
/// Tagmodus weisse Systemschrift auf hellem Grund. Der Bildschirmtitel gehorcht
/// weder dem noch `.tint` — er nimmt ausschliesslich `AccentColor` (im
/// Simulator geprueft: `.principal` gibt es auf watchOS nicht, und die
/// Dark-Variante des Assets wird nie gezogen). Deshalb traegt `AccentColor`
/// einen einzigen mittleren Grauton, der auf beiden Gruenden lesbar ist.
struct ThemeApplier: ViewModifier {
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    let settings: AppSettings

    func body(content: Content) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let night = luminanceReduced || settings.isNight(at: context.date)
            content.task(id: night) { ThemeState.shared.isNight = night }
                .environment(\.colorScheme, night ? .dark : .light)
        }
    }
}

/// Bändchen: die einzige Positionsanzeige (Messing). `position` = Beginn des
/// sichtbaren Ausschnitts (0…1), `extent` = dessen Anteil an der Gesamtlaenge.
struct Ribbon: View {
    let position: Double
    let extent: Double

    var body: some View {
        GeometryReader { geo in
            let height = max(8, geo.size.height * min(1, max(0, extent)))
            let offset = (geo.size.height - height) * min(1, max(0, position))
            ZStack(alignment: .top) {
                Capsule().fill(Color.ribbonTrack)
                Capsule().fill(Color.brass)
                    .frame(height: height)
                    .offset(y: offset)
            }
        }
        .frame(width: 2.5)
        .accessibilityHidden(true)
    }
}

/// Haptik beim Weiterschalten, abschaltbar (CLAUDE.md, Bedienung).
@MainActor
func playAdvanceHaptic(_ settings: AppSettings) {
    if settings.hapticsEnabled {
        WKInterfaceDevice.current().play(.click)
    }
}
