import Foundation

/// Datenmodelle. Spiegeln exakt das Schema von bible.sqlite (user_version 2).
/// Nicht abaendern, ohne quotepas_to_sqlite.py mitzuziehen.

struct Translation: Identifiable, Hashable, Sendable {
    let id: Int
    let code: String          // "elb", "kjv", …
    let abbrev: String        // "ELB"
    let name: String          // "Elberfelder 1905"
    let language: String      // "de" | "en" | "es" | "fr" | "zh-Hant" | "zh-Hans"
    let copyright: String?
    let verseCount: Int
    let firstVerseID: Int     // fuer den Zufallsvers: Int.random(in: first...last)
    let lastVerseID: Int
}

/// Ein Kapitel als Stelle ohne Vers — Ergebnis des Weiterblaetterns in der
/// Leseansicht. Kein Schemabestandteil, nur ein Rueckgabewert.
struct ChapterReference: Hashable, Sendable {
    let bookID: Int
    let chapter: Int
}

struct Book: Identifiable, Hashable, Sendable {
    let id: Int               // 1…66, kanonische Reihenfolge
    let code: String          // "1Mo", "Offb"
    let name: String          // "1. Mose" — Deutsch, Leitsprache der Datenbank
    /// Buchname je Anzeigesprache, Schluessel wie in `translation.language`
    /// ("de", "en", "es", "fr", "zh-Hant", "zh-Hans"). Deutsch steht mit
    /// darin, damit der Zugriff ohne Sonderfall auskommt.
    let names: [String: String]
    /// Buchkuerzel je Anzeigesprache, gleiche Schluessel. Fuer enge Stellen —
    /// Register der Buchliste, runde Komplikation. **Nicht mit `code`
    /// verwechseln**: der ist Schluessel und bleibt in jeder Sprache gleich.
    let abbreviations: [String: String]
    let testament: Testament
    let chapterCount: Int

    enum Testament: String, Sendable { case at = "AT", nt = "NT" }
}

/// Ein Thema des kuratierten Versregisters (`curated.topic`) samt Anzahl Verse.
///
/// Der deutsche Wert ist der **Schluessel** — wie `book.code` und aus demselben
/// Grund: er steht so in `curated_verses.json` und bleibt in jeder Sprache
/// gleich.
///
/// Anders als bei den Buchnamen steht die Schreibweise **nicht** in der
/// Datenbank, sondern im String Catalog unter «topic.<deutscher Wert>». Der
/// Unterschied ist kein Zufall: ein Buchname muss der Rechtschreibung der
/// Uebersetzung folgen, in der der Vers steht («Ruth» nach Reina-Valera) — er
/// haengt am Text. Ein Themenname haengt an nichts, er ist Beschriftung. Die
/// Datenbank sagt, **welche** Themen es gibt, der Katalog, **wie sie
/// geschrieben werden**; ein Unit-Test haelt beides deckungsgleich.
struct Topic: Identifiable, Hashable, Sendable {
    /// Deutscher Wert aus `curated.topic`. Zugleich der Katalogschluessel,
    /// mit `topic.` davor.
    let key: String
    let verseCount: Int

    var id: String { key }

    /// Schluessel im String Catalog. Enthaelt Leerzeichen und Umlaute
    /// («topic.Wort Gottes», «topic.Fuehrung» mit ue als Umlaut) — das ist
    /// zulaessig und erspart eine erfundene Kurzform, die als zweite Wahrheit
    /// neben `curated.topic` stuende.
    var localizationKey: String { "topic.\(key)" }
}

/// Eine Stellenangabe. Bewusst ohne Uebersetzung: dieselbe Referenz kann
/// je nach Uebersetzung auf unterschiedliche Texte zeigen (docs/Architektur.md, Kap. 5).
struct VerseReference: Hashable, Sendable, Codable {
    let bookID: Int
    let chapter: Int
    let verse: Int
}

struct Verse: Identifiable, Hashable, Sendable {
    let id: Int               // rowid, lueckenlos je Uebersetzung
    let translationID: Int
    let reference: VerseReference
    let bookName: String
    let text: String

    var displayReference: String { "\(bookName) \(reference.chapter),\(reference.verse)" }
}

/// Ergebnis eines Uebersetzungswechsels bei gleichbleibender Stelle.
enum VerseResolution: Sendable {
    /// Stelle existiert in der Zieluebersetzung, Verszaehlung des Kapitels stimmt ueberein.
    case exact(Verse)
    /// Stelle existiert, aber das Kapitel hat in beiden Uebersetzungen unterschiedlich
    /// viele Verse — die Zaehlung weicht ab, der Text kann eine andere Stelle sein.
    case divergent(Verse)
    /// Stelle existiert nicht; auf den letzten Vers des Kapitels geklemmt.
    case clamped(Verse, requested: Int)
    /// Kapitel existiert in der Zieluebersetzung ueberhaupt nicht.
    case unavailable
}
