import Foundation

/// Alles, was von der Anzeigesprache abhängt — und nur davon.
///
/// Grundregel: die Sprache bestimmt **Vorgaben**, nie eine getroffene Wahl.
/// Wer einmal eine Übersetzung ausgewählt hat, behält sie, auch wenn er später
/// die Systemsprache wechselt.
enum Localization {

    /// Die aktive Anzeigesprache der App, nicht die des Systems: `preferredLocalizations`
    /// liefert die Sprache, für die das Bundle tatsächlich Texte hat.
    static var displayLanguage: String {
        Bundle.main.preferredLocalizations.first.map { String($0.prefix(2)) } ?? "en"
    }

    /// Vorgabe für die Bibelübersetzung beim allerersten Start.
    /// Deutsch → Elberfelder 1905, Englisch → King James Version.
    static func defaultTranslationCode(available: [Translation]) -> String {
        let preferred = displayLanguage == "de" ? "elb" : "kjv"
        if available.contains(where: { $0.code == preferred }) { return preferred }
        // Zweite Wahl: irgendeine Übersetzung in der Anzeigesprache …
        if let sameLanguage = available.first(where: { $0.language == displayLanguage }) {
            return sameLanguage.code
        }
        // … sonst die erste der Datenbank.
        return available.first?.code ?? "elb"
    }

    /// Buchname in der Anzeigesprache. Die Datenbank führt beide Spalten;
    /// `name_en` ist für alle 66 Bücher gefüllt.
    static func name(of book: Book) -> String {
        displayLanguage == "en" ? (book.nameEN ?? book.name) : book.name
    }

    /// Stellenangabe. Der Trenner ist **nicht** kosmetisch: deutsche Bibeln
    /// schreiben «Johannes 3,16», englische «John 3:16». Darum über den
    /// String Catalog, nicht als fest verdrahtetes Zeichen.
    static func reference(_ ref: VerseReference, book: Book) -> String {
        String(localized: "reference.format %1$@ %2$lld %3$lld",
               defaultValue: "\(name(of: book)) \(ref.chapter),\(ref.verse)")
            .replacingOccurrences(of: "%1$@", with: name(of: book))
            .replacingOccurrences(of: "%2$lld", with: String(ref.chapter))
            .replacingOccurrences(of: "%3$lld", with: String(ref.verse))
    }

    /// Zahlen der Zählerzeile mit den Trennzeichen der jeweiligen Region:
    /// Schweizer Deutsch 18’463, Englisch 18,463.
    static func groupedNumber(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    /// Stellenangabe ohne Vers («Psalm 23» / "Psalm 23"). Der Katalogschlüssel
    /// verwendet Positionsangaben (%1$@ %2$lld); SwiftUI-Interpolation erzeugt
    /// %@ %lld und fände ihn nicht — darum String(format:).
    static func chapterReference(book: Book, chapter: Int) -> String {
        String(format: String(localized: "reference.chapter %1$@ %2$lld"),
               name(of: book), chapter)
    }

    /// Zählerzeile des Zufallsverses («18’463 / 31’103»).
    static func position(_ ordinal: Int, of total: Int) -> String {
        String(format: String(localized: "random.position %1$@ %2$@"),
               groupedNumber(ordinal), groupedNumber(total))
    }

    /// VoiceOver-Fassung der Zählerzeile.
    static func positionAccessibility(_ ordinal: Int, of total: Int) -> String {
        String(format: String(localized: "random.position.a11y %1$@ %2$@"),
               groupedNumber(ordinal), groupedNumber(total))
    }
}
