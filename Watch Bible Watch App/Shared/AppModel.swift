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

    func start() async {
        guard repository == nil else { return }
        do {
            let database = try BibleDatabase()
            let repo = BibleRepository(database: database)
            try await repo.load()
            translations = await repo.translations
            books = await repo.books
            // Sprachvorgabe nur beim allerersten Start; eine gewaehlte
            // Uebersetzung wird nie durch einen Sprachwechsel ueberschrieben.
            if !AppSettings.hasStoredTranslation {
                settings.translationCode =
                    Localization.defaultTranslationCode(available: translations)
            }
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
}

/// Navigationsziele. Werte statt Views, damit Stellen (Buch, Kapitel, Vers)
/// als Daten durch den NavigationStack wandern.
enum Route: Hashable {
    case random
    case books
    case chapters(bookID: Int)
    case verses(bookID: Int, chapter: Int)
    case reader(bookID: Int, chapter: Int, verse: Int?)
    case settings
    case translationPicker
    case about
}
