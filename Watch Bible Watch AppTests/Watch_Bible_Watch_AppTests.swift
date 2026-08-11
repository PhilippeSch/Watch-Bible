//
//  Watch_Bible_Watch_AppTests.swift
//  Watch Bible Watch AppTests
//
//  Unit-Tests der Datenschicht und Referenzaufloesung gegen test_fixtures.json.
//  Die Erwartungswerte wurden direkt aus der Datenbank erzeugt (siehe Konzept,
//  Kapitel 12); die Fixtures enthalten alle 29 Kapitel, in denen ELB und KJV
//  unterschiedlich viele Verse haben.
//

import Foundation
import Testing
@testable import Watch_Bible_Watch_App

// MARK: - Fixtures

private struct Fixtures: Decodable {
    struct Zaehlwerte: Decodable {
        let buecher: Int
        let kapitel: Int
        let verse_gesamt: Int
        let kuratiert: Int
        let uebersetzungen: [Uebersetzung]
    }
    struct Uebersetzung: Decodable {
        let code: String
        let language: String
        let verse_count: Int
        let first_verse_id: Int
        let last_verse_id: Int
    }
    struct Stichprobe: Decodable {
        let uebersetzung: String
        let buch: String
        let kapitel: Int
        let vers: Int
        let text: String
    }
    struct Versifikation: Decodable {
        let paare: [String: Paar]
    }
    struct Paar: Decodable {
        let anzahl: Int
        let faelle: [Fall]
    }
    struct Fall: Decodable {
        let buch: String
        let kapitel: Int
        private let counts: [String: Int]

        struct DynamicKey: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicKey.self)
            var buch = "", kapitel = 0, counts: [String: Int] = [:]
            for key in container.allKeys {
                switch key.stringValue {
                case "buch":    buch = try container.decode(String.self, forKey: key)
                case "kapitel": kapitel = try container.decode(Int.self, forKey: key)
                default:        counts[key.stringValue] = try container.decode(Int.self, forKey: key)
                }
            }
            self.buch = buch
            self.kapitel = kapitel
            self.counts = counts
        }

        func count(for code: String) -> Int? {
            // Fixture-Schluessel sind gekuerzt (elb, kjv), Datenbank-Codes teils
            // laenger (sch1951, rvr1909) — beides zulassen.
            counts[code] ?? counts.first { code.hasPrefix($0.key) }?.value
        }
    }

    let zaehlwerte: Zaehlwerte
    let stichproben: [Stichprobe]
    let versifikation: Versifikation
}

// MARK: - Gemeinsame Aufbauten

private final class BundleToken {}

private enum TestSupport {
    static let repositoryTask = Task<BibleRepository, Error> {
        let database = try BibleDatabase()   // bible.sqlite aus dem App-Bundle
        let repository = BibleRepository(database: database)
        try await repository.load()
        return repository
    }

    static let fixtures: Fixtures = {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "test_fixtures", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let fixtures = try? JSONDecoder().decode(Fixtures.self, from: data) else {
            fatalError("test_fixtures.json fehlt im Test-Bundle")
        }
        return fixtures
    }()

    static func repository() async throws -> BibleRepository {
        try await repositoryTask.value
    }
}

// MARK: - Zaehlwerte

struct ZaehlwerteTests {

    @Test func buecherUndUebersetzungen() async throws {
        let repo = try await TestSupport.repository()
        let fixtures = TestSupport.fixtures

        let books = await repo.books
        #expect(books.count == fixtures.zaehlwerte.buecher)
        #expect(books.filter { $0.testament == .at }.count == 39)
        #expect(books.filter { $0.testament == .nt }.count == 27)

        // book.chapter_count ist das Maximum ueber alle Uebersetzungen
        // (Joel: 4 wegen Schlachter 1951) — die 1'189 Kapitel gelten je
        // Uebersetzung und kommen aus chapter_meta.
        let elb = try #require(await repo.translations.first { $0.code == "elb" })
        var chapters = 0
        for book in books {
            chapters += try await repo.chapterVerseCounts(book: book.id, in: elb).count
        }
        #expect(chapters == fixtures.zaehlwerte.kapitel)

        let translations = await repo.translations
        #expect(translations.reduce(0) { $0 + $1.verseCount } == fixtures.zaehlwerte.verse_gesamt)
        for expected in fixtures.zaehlwerte.uebersetzungen {
            let actual = try #require(translations.first { $0.code == expected.code },
                                      "Uebersetzung \(expected.code) fehlt")
            #expect(actual.language == expected.language)
            #expect(actual.verseCount == expected.verse_count)
            #expect(actual.firstVerseID == expected.first_verse_id)
            #expect(actual.lastVerseID == expected.last_verse_id)
        }
    }
}

// MARK: - Stichproben

struct StichprobenTests {

    /// Alle Stichproben der Fixtures, darunter die Pflicht-Randfaelle
    /// 1Mo 1,1 · Ps 119,176 · Jud 1,25 · Offb 22,21.
    @Test func verseStimmenWoertlich() async throws {
        let repo = try await TestSupport.repository()
        let books = await repo.books
        let translations = await repo.translations

        for sample in TestSupport.fixtures.stichproben {
            let translation = try #require(translations.first { $0.code == sample.uebersetzung })
            let book = try #require(books.first { $0.code == sample.buch })
            let ref = VerseReference(bookID: book.id, chapter: sample.kapitel,
                                     verse: sample.vers)
            let verse = try #require(try await repo.verse(ref, in: translation),
                                     "\(sample.uebersetzung) \(sample.buch) \(sample.kapitel),\(sample.vers) fehlt")
            #expect(verse.text == sample.text)
        }
    }

    @Test func fehlenderVersIstNilKeinAbsturz() async throws {
        let repo = try await TestSupport.repository()
        let translations = await repo.translations
        let elb = try #require(translations.first { $0.code == "elb" })
        let ref = VerseReference(bookID: 1, chapter: 51, verse: 1)   // 1Mo hat 50 Kapitel
        let verse = try await repo.verse(ref, in: elb)
        #expect(verse == nil)
    }
}

// MARK: - Versifikation

struct VersifikationTests {

    /// Alle Kapitel mit abweichender Verszahl muessen beim Wechsel
    /// `.divergent` melden — nie stillschweigend `.exact`.
    @Test func abweichendeKapitelMeldenDivergent() async throws {
        let repo = try await TestSupport.repository()
        let books = await repo.books
        let translations = await repo.translations

        for (pairKey, pair) in TestSupport.fixtures.versifikation.paare {
            let codes = pairKey.split(separator: "_").map(String.init)
            guard codes.count == 2,
                  let source = translations.first(where: { $0.code.hasPrefix(codes[0]) }),
                  let target = translations.first(where: { $0.code.hasPrefix(codes[1]) }) else {
                Issue.record("Uebersetzungspaar \(pairKey) nicht aufloesbar")
                continue
            }
            #expect(pair.faelle.count == pair.anzahl)

            for fall in pair.faelle {
                let book = try #require(books.first { $0.code == fall.buch })
                if let expectedSource = fall.count(for: source.code) {
                    let actual = try await repo.verseCount(book: book.id,
                                                           chapter: fall.kapitel,
                                                           in: source)
                    #expect(actual == expectedSource,
                            "\(source.code) \(fall.buch) \(fall.kapitel): \(String(describing: actual)) statt \(expectedSource)")
                }
                if let expectedTarget = fall.count(for: target.code) {
                    let actual = try await repo.verseCount(book: book.id,
                                                           chapter: fall.kapitel,
                                                           in: target)
                    #expect(actual == expectedTarget)
                }

                let ref = VerseReference(bookID: book.id, chapter: fall.kapitel, verse: 1)
                let resolution = try await repo.resolve(ref, from: source, to: target)
                switch resolution {
                case .divergent:
                    break   // erwartet
                case .exact:
                    Issue.record("\(pairKey) \(fall.buch) \(fall.kapitel): .exact statt .divergent")
                case .clamped:
                    // Zulaessig nur, wenn Vers 1 im Ziel tatsaechlich fehlt
                    // (BSB Klagelieder 2 beginnt in dieser Quelle bei Vers 2).
                    let missing = try await repo.verse(ref, in: target) == nil
                    #expect(missing,
                            "\(pairKey) \(fall.buch) \(fall.kapitel): .clamped obwohl Vers 1 existiert")
                case .unavailable:
                    Issue.record("\(pairKey) \(fall.buch) \(fall.kapitel): unerwartete Aufloesung")
                }
            }
        }
    }

    /// Pflichtfall aus dem Konzept: 3Mo 5 hat in ELB 26, in KJV 19 Verse.
    /// ELB 5,26 → KJV muss auf das Kapitelende geklemmt und sichtbar werden.
    @Test func klemmtAufKapitelende() async throws {
        let repo = try await TestSupport.repository()
        let books = await repo.books
        let translations = await repo.translations
        let elb = try #require(translations.first { $0.code == "elb" })
        let kjv = try #require(translations.first { $0.code == "kjv" })
        let levitikus = try #require(books.first { $0.code == "3Mo" })

        let ref = VerseReference(bookID: levitikus.id, chapter: 5, verse: 26)
        let resolution = try await repo.resolve(ref, from: elb, to: kjv)
        guard case .clamped(let verse, let requested) = resolution else {
            Issue.record("Erwartet .clamped, erhalten \(resolution)")
            return
        }
        #expect(requested == 26)
        #expect(verse.reference.verse == 19)
    }

    /// Ganze Kapitel koennen fehlen: Joel 4 gibt es in dieser Datenbank nur
    /// in der Schlachter 1951, in der KJV nicht (dort ist es Joel 3).
    @Test func fehlendesKapitelIstUnavailable() async throws {
        let repo = try await TestSupport.repository()
        let books = await repo.books
        let translations = await repo.translations
        let sch = try #require(translations.first { $0.code == "sch1951" })
        let kjv = try #require(translations.first { $0.code == "kjv" })
        let joel = try #require(books.first { $0.code == "Joel" })

        let ref = VerseReference(bookID: joel.id, chapter: 4, verse: 1)
        let resolution = try await repo.resolve(ref, from: sch, to: kjv)
        guard case .unavailable = resolution else {
            Issue.record("Erwartet .unavailable, erhalten \(resolution)")
            return
        }
    }
}

// MARK: - Sprachen

/// Die Oberflaeche soll es in jeder Sprache geben, fuer die eine
/// Bibeluebersetzung mitgeliefert wird — und die Vorgabe soll die erste
/// Uebersetzung dieser Sprache in der Reihenfolge der Datenbank sein.
struct SprachenTests {

    /// Der Bezugspunkt: keine Uebersetzungssprache ohne Oberflaeche.
    /// Kommt eine siebte Sprache in die Datenbank, faellt dieser Test um.
    @Test func jedeUebersetzungssspracheHatEineOberflaeche() async throws {
        let repo = try await TestSupport.repository()
        let sprachen = Set(await repo.translations.map(\.language))
        let oberflaeche = Set(Localization.supportedLanguages)
        #expect(sprachen.subtracting(oberflaeche).isEmpty,
                "Uebersetzung ohne Oberflaechensprache: \(sprachen.subtracting(oberflaeche))")
        // Umgekehrt ebenso: keine Oberflaeche ohne eigene Uebersetzung.
        #expect(oberflaeche.subtracting(sprachen).isEmpty,
                "Oberflaechensprache ohne Uebersetzung: \(oberflaeche.subtracting(sprachen))")
    }

    /// Auch als Bundle-Lokalisierung muss jede Sprache vorhanden sein —
    /// sonst zeigt das Geraet trotz uebersetzter Texte die Leitsprache.
    @Test func jedeSpracheIstImBundleLokalisiert() async throws {
        let vorhanden = Set(Bundle.main.localizations)
        for sprache in Localization.supportedLanguages {
            #expect(vorhanden.contains(sprache),
                    "Lokalisierung \(sprache) fehlt im Bundle: \(vorhanden.sorted())")
        }
    }

    /// Vorgabe = erste Uebersetzung dieser Sprache in Datenbankreihenfolge.
    /// Nichts davon ist im Code hinterlegt; die Erwartung wird aus der
    /// Datenbank selbst abgeleitet.
    @Test func vorgabeIstDieErsteUebersetzungDerSprache() async throws {
        let repo = try await TestSupport.repository()
        let translations = await repo.translations

        for sprache in Localization.supportedLanguages {
            let erwartet = try #require(translations.first { $0.language == sprache },
                                        "keine Uebersetzung fuer \(sprache)")
            let gewaehlt = Localization.defaultTranslationCode(available: translations,
                                                              language: sprache)
            #expect(gewaehlt == erwartet.code,
                    "\(sprache): \(gewaehlt) statt \(erwartet.code)")
        }
    }

    /// Unbekannte Systemsprache: Englisch, kein Absturz, kein leerer Code.
    @Test func unbekannteSpracheFaelltAufEnglischZurueck() async throws {
        let repo = try await TestSupport.repository()
        let translations = await repo.translations
        let code = Localization.defaultTranslationCode(available: translations,
                                                       language: "it")
        let englisch = try #require(translations.first { $0.language == "en" })
        #expect(code == englisch.code)
    }

    /// Sprachkennungen des Systems auf die Schreibweise der Datenbank.
    @Test func sprachkennungenWerdenNormalisiert() {
        #expect(Localization.normalized("de") == "de")
        #expect(Localization.normalized("de-CH") == "de")
        #expect(Localization.normalized("en-GB") == "en")
        #expect(Localization.normalized("es-419") == "es")
        #expect(Localization.normalized("fr-CA") == "fr")
        // Chinesisch unterscheidet sich in der Schrift, nicht in der Sprache.
        #expect(Localization.normalized("zh-Hant") == "zh-Hant")
        #expect(Localization.normalized("zh-Hans") == "zh-Hans")
        #expect(Localization.normalized("zh-TW") == "zh-Hant")
        #expect(Localization.normalized("zh-HK") == "zh-Hant")
        #expect(Localization.normalized("zh-CN") == "zh-Hans")
        #expect(Localization.normalized("zh") == "zh-Hans")
        // Sprache ohne Uebersetzung
        #expect(Localization.normalized("it") == "en")
    }

    /// Die Sprache der Oberflaeche steht in der Auswahl zuoberst, der Rest
    /// bleibt in Datenbankreihenfolge.
    @Test func anzeigespracheStehtZuoberst() async throws {
        let repo = try await TestSupport.repository()
        let translations = await repo.translations
        // Unbekannte Sprache: reine Datenbankreihenfolge, nichts wird umgestellt.
        var gesehen: Set<String> = []
        let datenbankreihenfolge = translations.map(\.language)
            .filter { gesehen.insert($0).inserted }
        #expect(Localization.languageOrder(of: translations, first: "it")
                == datenbankreihenfolge)

        for sprache in Localization.supportedLanguages {
            let reihenfolge = Localization.languageOrder(of: translations, first: sprache)
            #expect(reihenfolge.first == sprache, "\(sprache) nicht zuoberst")
            #expect(Array(reihenfolge.dropFirst())
                    == datenbankreihenfolge.filter { $0 != sprache },
                    "\(sprache): Rest nicht in Datenbankreihenfolge")
        }
    }

    /// Buchnamen: alle 66 Buecher in allen sechs Sprachen, ohne Rueckfall
    /// auf den deutschen Namen.
    @Test func buchnamenLiegenInAllenSprachenVor() async throws {
        let repo = try await TestSupport.repository()
        let books = await repo.books

        for sprache in Localization.supportedLanguages {
            let ohne = books.filter { $0.names[sprache] == nil }
            #expect(ohne.isEmpty,
                    "\(sprache): kein Name fuer \(ohne.map(\.code).joined(separator: ", "))")
            // Keine zwei Buecher duerfen in derselben Sprache gleich heissen.
            let namen = books.compactMap { $0.names[sprache] }
            #expect(Set(namen).count == namen.count, "\(sprache): doppelte Buchnamen")
        }
    }

    /// Stichproben quer durch die Sprachen — Randfaelle des Konzepts.
    @Test func buchnamenStimmen() async throws {
        let repo = try await TestSupport.repository()
        let books = await repo.books
        let erwartet: [String: [String: String]] = [
            "1Mo":  ["de": "1. Mose", "en": "Genesis", "es": "Génesis",
                     "fr": "Genèse", "zh-Hant": "創世記", "zh-Hans": "创世记"],
            "Ps":   ["de": "Psalmen", "en": "Psalms", "es": "Salmos",
                     "fr": "Psaumes", "zh-Hant": "詩篇", "zh-Hans": "诗篇"],
            "Jud":  ["de": "Judas", "en": "Jude", "es": "Judas",
                     "fr": "Jude", "zh-Hant": "猶大書", "zh-Hans": "犹大书"],
            "Offb": ["de": "Offenbarung", "en": "Revelation", "es": "Apocalipsis",
                     "fr": "Apocalypse", "zh-Hant": "啟示錄", "zh-Hans": "启示录"],
        ]
        for (code, namen) in erwartet {
            let book = try #require(books.first { $0.code == code })
            for (sprache, name) in namen {
                #expect(Localization.name(of: book, in: sprache) == name,
                        "\(code) \(sprache): \(Localization.name(of: book, in: sprache))")
            }
        }
    }

    /// Jede Sprache braucht ihre Stellenangabe: Deutsch Komma, die uebrigen
    /// Doppelpunkt. Fehlt der Schluessel, gaebe der Katalog ihn selbst zurueck.
    @Test func stellenformatIstJeSpracheUebersetzt() throws {
        let bundle = Bundle.main
        for sprache in Localization.supportedLanguages {
            let pfad = try #require(bundle.path(forResource: sprache, ofType: "lproj"),
                                    "\(sprache).lproj fehlt")
            let sprachbundle = try #require(Bundle(path: pfad))
            let schluessel = "reference.format %1$@ %2$lld %3$lld"
            let format = sprachbundle.localizedString(forKey: schluessel, value: "",
                                                      table: nil)
            #expect(!format.isEmpty, "\(sprache): kein Stellenformat")
            #expect(format.contains(sprache == "de" ? "," : ":"),
                    "\(sprache): Trenner falsch — \(format)")
            let stelle = String(format: format, "Johannes", Int64(3), Int64(16))
            #expect(stelle == (sprache == "de" ? "Johannes 3,16" : "Johannes 3:16"))
        }
    }
}

// MARK: - Zufall und Vers des Tages

struct ZufallTests {

    @Test func zufallsversLiegtInDenGrenzen() async throws {
        let repo = try await TestSupport.repository()
        let translations = await repo.translations
        let elb = try #require(translations.first { $0.code == "elb" })

        for _ in 0..<25 {
            let verse = try #require(try await repo.randomVerse(in: elb))
            #expect(verse.id >= elb.firstVerseID && verse.id <= elb.lastVerseID)
            #expect(verse.translationID == elb.id)
        }
    }

    @Test func kuratierterZufallsversKommtAusDerListe() async throws {
        let repo = try await TestSupport.repository()
        let translations = await repo.translations
        let elb = try #require(translations.first { $0.code == "elb" })
        let verse = try #require(try await repo.randomCuratedVerse(in: elb))
        #expect(!verse.text.isEmpty)
    }

    /// Das Widget braucht Determinismus: gleicher Tag, gleicher Vers.
    @Test func versDesTagesIstDeterministisch() async throws {
        let repo = try await TestSupport.repository()
        let translations = await repo.translations
        let elb = try #require(translations.first { $0.code == "elb" })

        let date = Date(timeIntervalSince1970: 1_754_000_000)
        let first = try #require(try await repo.verseOfDay(for: date, in: elb))
        let second = try #require(try await repo.verseOfDay(for: date, in: elb))
        #expect(first.id == second.id)

        let nextDay = date.addingTimeInterval(86_400)
        let third = try #require(try await repo.verseOfDay(for: nextDay, in: elb))
        #expect(third.id != first.id)
    }
}
