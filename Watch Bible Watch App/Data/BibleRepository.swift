import Foundation

/// Fachliche Zugriffsschicht. Alle SQL-Abfragen hier wurden gegen die echte
/// Datenbank geprueft (EXPLAIN QUERY PLAN: durchgaengig Indexzugriff, kein
/// Table Scan). Reihenfolge und Spalten der SELECTs nicht veraendern, ohne die
/// map-Closures mitzuziehen.
actor BibleRepository {

    private let db: BibleDatabase
    private(set) var translations: [Translation] = []
    private(set) var books: [Book] = []
    /// Themen des Versregisters, in Datenbankreihenfolge (alphabetisch nach
    /// dem deutschen Schluessel). Die Anzeigereihenfolge macht die Oberflaeche.
    private(set) var topics: [Topic] = []
    private var curatedCount: Int = 0
    /// Stellen je Thema, einmal beim Start gelesen. Es sind wenige hundert
    /// Referenzen — billiger als eine Abfrage je Zufallsvers, und der
    /// Zufallszug bleibt damit ein Griff ins Array.
    private var curatedByTopic: [String: [VerseReference]] = [:]

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
                           ("it", "name_it"), ("pt", "name_pt"),
                           ("zh-Hant", "name_zh_hant"), ("zh-Hans", "name_zh_hans")]
            .filter { columns.contains($0.1) }
        let abbrevColumns = [("de", "abbrev_de"), ("en", "abbrev_en"),
                             ("es", "abbrev_es"), ("fr", "abbrev_fr"),
                             ("it", "abbrev_it"), ("pt", "abbrev_pt"),
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
        try await loadTopics()
    }

    /// Themenregister: welche Themen es gibt und welche Stellen dazugehoeren.
    /// Wie ein Thema geschrieben wird, steht im String Catalog — hier nicht.
    private func loadTopics() async throws {
        let rows = try await db.query("""
            SELECT topic, book_id, chapter, verse FROM curated
             WHERE topic IS NOT NULL ORDER BY topic, id
            """) { r in
            (r.string(0), VerseReference(bookID: r.int(1), chapter: r.int(2),
                                         verse: r.int(3)))
        }

        var references: [String: [VerseReference]] = [:]
        var order: [String] = []
        for (topic, reference) in rows {
            if references[topic] == nil { order.append(topic) }
            references[topic, default: []].append(reference)
        }
        curatedByTopic = references
        topics = order.map { key in
            Topic(key: key, verseCount: references[key]?.count ?? 0)
        }
    }

    func topic(key: String) -> Topic? { topics.first { $0.key == key } }

    /// Die Stellen eines Themas, in Datenbankreihenfolge. Unbekanntes Thema
    /// ergibt eine leere Liste.
    func references(topic key: String) -> [VerseReference] {
        curatedByTopic[key] ?? []
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

    /// Zufallsvers aus der kuratierten Auswahl (Themenregister der Datenbank).
    ///
    /// Mit `seed` liefert derselbe Startwert dieselbe Ziehung. Das Widget setzt
    /// die Nummer des Kalendertages ein: der Vers steht damit von Mitternacht
    /// bis Mitternacht, und jede Neuberechnung der Zeitleiste bestaetigt ihn,
    /// statt einen anderen zu zeigen. Ohne `seed` wird der Startwert selbst
    /// gewuerfelt — das ist der Zufallsvers der App.
    func randomCuratedVerse(in translation: Translation,
                            excluding recent: Set<Int> = [],
                            seed: UInt64? = nil) async throws -> Verse? {
        guard curatedCount > 0 else { return nil }
        var rng = SeededGenerator(seed: seed ?? .random(in: 0...UInt64.max))
        for _ in 0..<8 {
            let offset = Int.random(in: 0..<curatedCount, using: &rng)
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

    /// Zufallsvers aus genau einem Thema.
    ///
    /// Die Stellen des Themas liegen bereits im Speicher, gezogen wird darum in
    /// Swift statt in SQL. Gesperrt wird ueber die **Stelle**, nicht ueber
    /// `verse.id`: dieselbe Stelle hat je Uebersetzung eine andere id, und die
    /// Sperre soll auch nach einem Uebersetzungswechsel greifen.
    ///
    /// Die Liste wird gemischt und die erste Stelle genommen, die es in dieser
    /// Uebersetzung wirklich gibt — ein Thema kann eine Stelle enthalten, die
    /// in einer anderen Versifikation fehlt (docs/Architektur.md, Kap. 5). Sind alle
    /// Stellen gesperrt, faellt die Sperre fuer diesen Zug weg, statt nichts zu
    /// liefern.
    func randomCuratedVerse(in translation: Translation, topic key: String,
                            excluding recent: Set<VerseReference> = []) async throws -> Verse? {
        guard let references = curatedByTopic[key], !references.isEmpty else {
            return nil
        }
        let open = references.filter { !recent.contains($0) }
        for ref in (open.isEmpty ? references : open).shuffled() {
            if let verse = try await verse(ref, in: translation) { return verse }
        }
        return nil
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

    // MARK: - Weiterblaettern

    /// Das Kapitel vor oder nach diesem — in **dieser** Uebersetzung und ueber
    /// Buchgrenzen hinweg. `nil` heisst Kanonende: vor 1Mo 1 und nach dem
    /// letzten Kapitel der Offenbarung gibt es nichts mehr.
    ///
    /// Massgeblich ist `chapter_meta`, **nicht `book.chapter_count`**: dort
    /// steht das Maximum ueber alle Uebersetzungen. Joel fuehrt darin vier
    /// Kapitel, hat aber in zehn von zwoelf Uebersetzungen nur drei; Maleachi
    /// umgekehrt. Wer nach `chapter_count` blaettert, landet auf einem leeren
    /// Kapitel — kein Absturz, nur eine leere Seite ohne Erklaerung.
    func adjacentChapter(book bookID: Int, chapter: Int, offset: Int,
                         in translation: Translation) async throws -> ChapterReference? {
        let direction = offset < 0 ? -1 : 1
        let here = try await chapterVerseCounts(book: bookID, in: translation)
        let target = chapter + direction
        if here[target] != nil {
            return ChapterReference(bookID: bookID, chapter: target)
        }
        // Buchgrenze. Ein Buch, das diese Uebersetzung gar nicht fuehrt, wird
        // uebersprungen — vorkommen sollte das nicht, kosten tut es nichts.
        guard var index = books.firstIndex(where: { $0.id == bookID }) else { return nil }
        index += direction
        while books.indices.contains(index) {
            let neighbour = books[index]
            let list = try await chapterVerseCounts(book: neighbour.id, in: translation)
            if let edge = direction > 0 ? list.keys.min() : list.keys.max() {
                return ChapterReference(bookID: neighbour.id, chapter: edge)
            }
            index += direction
        }
        return nil
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

/// Zufallszahlen mit festem Startwert (SplitMix64). Gleicher Startwert,
/// gleiche Folge — anders als `SystemRandomNumberGenerator`, der bei jedem
/// Aufruf neu wuerfelt. Rechnet durchgaengig in UInt64, weil `Int` auf
/// watchOS 32 Bit breit ist.
private struct SeededGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
