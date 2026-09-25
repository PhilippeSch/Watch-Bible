import SwiftUI

/// Zentraler App-Zustand: oeffnet die Datenbank einmal beim Start, haelt die
/// Stammdaten (Uebersetzungen, Buecher) und die aktive Uebersetzung.
@MainActor
@Observable
final class AppModel {

    enum LoadState {
        case loading
        case ready
        case failed(String)
    }

    let settings = AppSettings()
    private(set) var state: LoadState = .loading
    private(set) var repository: BibleRepository?
    private(set) var translations: [Translation] = []
    private(set) var books: [Book] = []
    private(set) var topics: [Topic] = []
    /// Anzahl Verse des Versregisters, ueber alle Themen. Bezugsgroesse der
    /// Zaehlerzeile, wenn der Zufallsvers aus dem Register zieht.
    private(set) var curatedCount: Int = 0

    func start() async {
        guard repository == nil else { return }
        do {
            let database = try BibleDatabase()
            let repo = BibleRepository(database: database)
            try await repo.load()
            translations = await repo.translations
            books = await repo.books
            topics = await repo.topics
            curatedCount = await repo.curatedCount
            // Eine gewaehlte Uebersetzung bleibt; eine blosse Sprachvorgabe
            // folgt der Anzeigesprache, auch nach einem Sprachwechsel.
            settings.applyTranslation(
                Localization.startupTranslationCode(
                    stored: settings.translationCode,
                    pickedByUser: settings.translationPickedByUser,
                    available: translations))
            repository = repo
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Aktive Uebersetzung. Existiert der gespeicherte Code in dieser
    /// Datenbank nicht (etwa nach einem Datenbankwechsel), greift die
    /// Sprachvorgabe — ohne die gespeicherte Wahl zu ueberschreiben.
    var translation: Translation? {
        translations.first { $0.code == settings.translationCode }
            ?? translations.first {
                $0.code == Localization.defaultTranslationCode(available: translations)
            }
            ?? translations.first
    }

    func book(id: Int) -> Book? {
        books.first { $0.id == id }
    }

    func topic(key: String) -> Topic? {
        topics.first { $0.key == key }
    }
}

/// Navigationsziele. Werte statt Views, damit Stellen (Buch, Kapitel, Vers)
/// als Daten durch den NavigationStack wandern.
enum Route: Hashable {
    case random
    case topics
    /// Zufallsvers, auf ein Thema beschraenkt. Uebergeben wird der Schluessel
    /// (der deutsche Wert aus `curated.topic`), nicht der Anzeigename.
    case topicVerses(key: String)
    case books
    case chapters(bookID: Int)
    case verses(bookID: Int, chapter: Int)
    /// `sourceTranslation`: Code der Uebersetzung, aus der die Stelle stammt,
    /// falls es nicht die aktive ist (Deep Link des Widgets). Die Leseansicht
    /// gleicht sie dann einmal ueber `resolve` ab, wie einen Wechsel.
    case reader(bookID: Int, chapter: Int, verse: Int?, sourceTranslation: String? = nil)
    case settings
    case translationPicker
    case about
}
