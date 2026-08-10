import Foundation

/// Datenmodelle. Spiegeln exakt das Schema von bible.sqlite (user_version 1).
/// Nicht abaendern, ohne quotepas_to_sqlite.py mitzuziehen.

struct Translation: Identifiable, Hashable, Sendable {
    let id: Int
    let code: String          // "elb", "kjv", …
    let abbrev: String        // "ELB"
    let name: String          // "Elberfelder 1905"
    let language: String      // "de" | "en"
    let copyright: String?
    let verseCount: Int
    let firstVerseID: Int     // fuer den Zufallsvers: Int.random(in: first...last)
    let lastVerseID: Int
}

struct Book: Identifiable, Hashable, Sendable {
    let id: Int               // 1…66, kanonische Reihenfolge
    let code: String          // "1Mo", "Offb"
    let name: String          // "1. Mose"
    let nameEN: String?
    let testament: Testament
    let chapterCount: Int

    enum Testament: String, Sendable { case at = "AT", nt = "NT" }
}

/// Eine Stellenangabe. Bewusst ohne Uebersetzung: dieselbe Referenz kann
/// je nach Uebersetzung auf unterschiedliche Texte zeigen (siehe Konzept, Kap. 6).
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
