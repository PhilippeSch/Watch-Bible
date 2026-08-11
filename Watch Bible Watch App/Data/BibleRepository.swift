import Foundation

/// Fachliche Zugriffsschicht. Alle SQL-Abfragen hier wurden gegen die echte
/// Datenbank geprueft (EXPLAIN QUERY PLAN: durchgaengig Indexzugriff, kein
/// Table Scan). Reihenfolge und Spalten der SELECTs nicht veraendern, ohne die
/// map-Closures mitzuziehen.
actor BibleRepository {

    private let db: BibleDatabase
    private(set) var translations: [Translation] = []
    private(set) var books: [Book] = []
    private var curatedCount: Int = 0

    init(database: BibleDatabase) {
        self.db = database
    }

    /// Einmal beim Start aufrufen. Laedt die Stammdaten (66 Buecher, wenige
    /// Uebersetzungen) in den Speicher — das sind wenige Kilobyte.
    func load() async throws {
        translations = try await db.query("""
            SELECT id, code, abbrev, name, language, copyright,
                   verse_count, first_verse_id, last_verse_id
              FROM translation ORDER BY sort_order
            """) { r in
            Translation(id: r.int(0), code: r.string(1), abbrev: r.string(2),
                        name: r.string(3), language: r.string(4),
                        copyright: r.stringOrNil(5), verseCount: r.int(6),
                        firstVerseID: r.int(7), lastVerseID: r.int(8))
        }
        // Buchnamen je Anzeigesprache. Die Namensspalten werden erst gesucht
        // und dann angehaengt, statt fest in die Abfrage geschrieben: eine
        // Datenbank aus einem aelteren Konverterlauf kennt sie noch nicht, und
        // ein `no such column` beim Vorbereiten wuerde die ganze App lahmlegen.
        // Fehlt eine Spalte, bleibt fuer diese Sprache der deutsche Name stehen
        // (tools/add_book_names.py traegt sie nach).
        let columns = Set(try await db.query("PRAGMA table_info(book)") { $0.string(1) })
        let nameColumns = [("en", "name_en"), ("es", "name_es"), ("fr", "name_fr"),
                           ("zh-Hant", "name_zh_hant"), ("zh-Hans", "name_zh_hans")]
            .filter { columns.contains($0.1) }
        let abbrevColumns = [("de", "abbrev_de"), ("en", "abbrev_en"),
                             ("es", "abbrev_es"), ("fr", "abbrev_fr"),
                             ("zh-Hant", "abbrev_zh_hant"),
                             ("zh-Hans", "abbrev_zh_hans")]
            .filter { columns.contains($0.1) }
        let fixed = ["id", "code", "name", "testament", "chapter_count"]
        let selection = (fixed + nameColumns.map(\.1) + abbrevColumns.map(\.1))
            .joined(separator: ", ")
        let nameBase = Int32(fixed.count)
        let abbrevBase = nameBase + Int32(nameColumns.count)
        books = try await db.query("""
            SELECT \(selection) FROM book ORDER BY sort_order
            """) { r in
            var names = ["de": r.string(2)]
            for (offset, column) in nameColumns.enumerated() {
                if let name = r.stringOrNil(nameBase + Int32(offset)) {
                    names[column.0] = name
                }
            }
            var abbreviations: [String: String] = [:]
            for (offset, column) in abbrevColumns.enumerated() {
                if let abbrev = r.stringOrNil(abbrevBase + Int32(offset)) {
                    abbreviations[column.0] = abbrev
                }
            }
            return Book(id: r.int(0), code: r.string(1), name: r.string(2),
                        names: names, abbreviations: abbreviations,
                        testament: Book.Testament(rawValue: r.string(3)) ?? .at,
                        chapterCount: r.int(4))
        }
        curatedCount = try await db.queryOne("SELECT COUNT(*) FROM curated") {
            $0.int(0)
        } ?? 0
    }

    func translation(code: String) -> Translation? {
        translations.first { $0.code == code }
    }

    func book(id: Int) -> Book? { books.first { $0.id == id } }

    // MARK: - Zufallsvers

    /// Gleichverteilt ueber die ganze Bibel. Ein einziger Primaerschluessel-
    /// zugriff, weil verse.id je Uebersetzung lueckenlos ist.
    /// NIEMALS durch ORDER BY RANDOM() ersetzen — das scannt 31'000 Zeilen.
    func randomVerse(in translation: Translation,
                     excluding recent: Set<Int> = []) async throws -> Verse? {
        for _ in 0..<8 {   // Wiederholungssperre, danach aufgeben
            let id = Int.random(in: translation.firstVerseID...translation.lastVerseID)
            if recent.contains(id) { continue }
            if let verse = try await verse(id: id) { return verse }
        }
        return try await verse(id: Int.random(in: translation.firstVerseID...translation.lastVerseID))
    }

    /// Zufallsvers aus der kuratierten Auswahl (180 Kernverse).
    func randomCuratedVerse(in translation: Translation,
                            excluding recent: Set<Int> = []) async throws -> Verse? {
        guard curatedCount > 0 else { return nil }
        for _ in 0..<8 {
            let offset = Int.random(in: 0..<curatedCount)
            guard let ref = try await db.queryOne("""
                SELECT book_id, chapter, verse FROM curated
                 ORDER BY id LIMIT 1 OFFSET ?
                """, [offset], map: { r in
                    VerseReference(bookID: r.int(0), chapter: r.int(1), verse: r.int(2))
                }) else { continue }
            if let verse = try await verse(ref, in: translation),
               !recent.contains(verse.id) {
                return verse
            }
        }
        return nil
    }

    /// Deterministischer Vers des Tages — gleiche Eingabe, gleiches Ergebnis.
    /// Das Widget darf keinen Zufall verwenden, sonst wechselt der Vers bei
    /// jeder Zeitleisten-Aktualisierung.
    func verseOfDay(for date: Date, in translation: Translation) async throws -> Verse? {
        guard curatedCount > 0 else { return nil }
        let day = Calendar(identifier: .gregorian)
            .ordinality(of: .day, in: .era, for: date) ?? 0
        let offset = day % curatedCount
        guard let ref = try await db.queryOne("""
            SELECT book_id, chapter, verse FROM curated ORDER BY id LIMIT 1 OFFSET ?
            """, [offset], map: { r in
                VerseReference(bookID: r.int(0), chapter: r.int(1), verse: r.int(2))
            }) else { return nil }
        return try await verse(ref, in: translation)
    }

    // MARK: - Nachschlagen

    func verse(id: Int) async throws -> Verse? {
        try await db.queryOne("""
            SELECT v.id, v.translation_id, v.book_id, v.chapter, v.verse, v.text, b.name
              FROM verse v JOIN book b ON b.id = v.book_id
             WHERE v.id = ?
            """, [id]) { r in
            Verse(id: r.int(0), translationID: r.int(1),
                  reference: VerseReference(bookID: r.int(2), chapter: r.int(3),
                                            verse: r.int(4)),
                  bookName: r.string(6), text: r.string(5))
        }
    }

    func verse(_ ref: VerseReference, in translation: Translation) async throws -> Verse? {
        try await db.queryOne("""
            SELECT v.id, v.text, b.name FROM verse v JOIN book b ON b.id = v.book_id
             WHERE v.translation_id = ? AND v.book_id = ? AND v.chapter = ? AND v.verse = ?
            """, [translation.id, ref.bookID, ref.chapter, ref.verse]) { r in
            Verse(id: r.int(0), translationID: translation.id, reference: ref,
                  bookName: r.string(2), text: r.string(1))
        }
    }

    /// Ganzes Kapitel — Grundlage der Leseansicht.
    func chapter(book bookID: Int, chapter: Int,
                 in translation: Translation) async throws -> [Verse] {
        let name = book(id: bookID)?.name ?? ""
        return try await db.query("""
            SELECT id, verse, text FROM verse
             WHERE translation_id = ? AND book_id = ? AND chapter = ?
             ORDER BY verse
            """, [translation.id, bookID, chapter]) { r in
            Verse(id: r.int(0), translationID: translation.id,
                  reference: VerseReference(bookID: bookID, chapter: chapter,
                                            verse: r.int(1)),
                  bookName: name, text: r.string(2))
        }
    }

    /// Verszahlen je Kapitel — fuellt die Auswahlraster ohne COUNT-Abfragen.
    func chapterVerseCounts(book bookID: Int,
                            in translation: Translation) async throws -> [Int: Int] {
        let rows = try await db.query("""
            SELECT chapter, verse_count FROM chapter_meta
             WHERE translation_id = ? AND book_id = ? ORDER BY chapter
            """, [translation.id, bookID]) { ($0.int(0), $0.int(1)) }
        return Dictionary(uniqueKeysWithValues: rows)
    }

    func verseCount(book bookID: Int, chapter: Int,
                    in translation: Translation) async throws -> Int? {
        try await db.queryOne("""
            SELECT verse_count FROM chapter_meta
             WHERE translation_id = ? AND book_id = ? AND chapter = ?
            """, [translation.id, bookID, chapter]) { $0.int(0) }
    }

    // MARK: - Uebersetzungswechsel

    /// Loest eine Stelle in einer anderen Uebersetzung auf.
    ///
    /// Wichtig: dieselbe Stellenangabe bezeichnet nicht zwingend denselben Text.
    /// In dieser Datenbank haben 136 von 1189 Kapiteln zwischen Schlachter und
    /// KJV unterschiedliche Verszahlen, teils durch verschobene Kapitelgrenzen
    /// (4Mo 16/17, 3Mo 5/6, Joel 3/4). Weicht die Verszahl des Kapitels ab, wird
    /// das Ergebnis als `.divergent` markiert — die Oberflaeche muss das sichtbar
    /// machen, sonst zeigt die App stillschweigend den falschen Vers.
    func resolve(_ ref: VerseReference, from source: Translation,
                 to target: Translation) async throws -> VerseResolution {
        guard let targetCount = try await verseCount(book: ref.bookID,
                                                     chapter: ref.chapter,
                                                     in: target) else {
            return .unavailable
        }
        let sourceCount = try await verseCount(book: ref.bookID,
                                               chapter: ref.chapter, in: source)
        let diverges = sourceCount != nil && sourceCount != targetCount

        if let verse = try await verse(ref, in: target) {
            return diverges ? .divergent(verse) : .exact(verse)
        }
        let clampedRef = VerseReference(bookID: ref.bookID, chapter: ref.chapter,
                                        verse: targetCount)
        guard let verse = try await verse(clampedRef, in: target) else {
            return .unavailable
        }
        return .clamped(verse, requested: ref.verse)
    }
}
