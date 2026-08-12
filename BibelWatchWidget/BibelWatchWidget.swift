import WidgetKit
import SwiftUI

/// Vers des Tages (docs/Architektur.md, Kap. 8): jeder Kalendertag zieht einen eigenen
/// Zufallsvers aus der kuratierten Auswahl — mit der Tagesnummer als Startwert,
/// damit der Vers von Mitternacht bis Mitternacht steht und jede Neuberechnung
/// der Zeitleiste denselben liefert. Die Zeitleiste traegt sieben Tage vor.
/// Tippen oeffnet die App auf demselben Vers (widgetURL).
///
/// Bewusst ohne App Group: das Widget liest keine UserDefaults und folgt der
/// Systemsprache (de → ELB, en → KJV). Damit bleibt das Privacy-Manifest der
/// App bei Reason CA92.1.
@main
struct BibelWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        VerseOfDayWidget()
    }
}

struct VerseOfDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VerseOfDay", provider: VerseOfDayProvider()) { entry in
            VerseWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.black }
                .widgetURL(entry.url)
        }
        .configurationDisplayName(Text("widget.name"))
        .description(Text("widget.description"))
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

struct VerseEntry: TimelineEntry {
    let date: Date
    let reference: String       // «Johannes 3,16»
    /// Buchkuerzel der Anzeigesprache fuer die runde Komplikation
    /// («Joh» · «John» · «Jn» · «約»). Nicht book.code: der ist deutsch.
    let bookAbbrev: String
    /// Kapitel und Vers, fertig gesetzt mit dem Trenner der Anzeigesprache
    /// («3,16» deutsch, «3:16» sonst). Hier steht die fertige Zeichenkette und
    /// nicht zwei Zahlen: der Trenner gehoert in den String Catalog, und die
    /// Ansicht soll ihn nicht selber setzen muessen.
    let chapterVerse: String
    let text: String
    let url: URL?

    static let placeholder = VerseEntry(
        date: .now,
        reference: "Johannes 3,16", bookAbbrev: "Joh", chapterVerse: "3,16",
        text: "Denn also hat Gott die Welt geliebt, dass er seinen eingeborenen Sohn gab …",
        url: nil)
}

struct VerseOfDayProvider: TimelineProvider {

    func placeholder(in context: Context) -> VerseEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (VerseEntry) -> Void) {
        Task {
            let entries = await loadEntries(days: 1)
            completion(entries.first ?? .placeholder)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<VerseEntry>) -> Void) {
        Task {
            let entries = await loadEntries(days: 7)
            // .atEnd: nach dem letzten Eintrag (Tag 7) neu laden.
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    /// Die Datenbank liegt nur einmal im Paket — im Bundle der App. Die
    /// .appex steckt in <App>.app/PlugIns/, zwei Ebenen hoeher liegt die
    /// Ressource. Eine zweite Kopie im Widget wuerde das 75-MB-Limit sprengen
    /// (44 MB × 2), gemessen am Archiv vom 10. August 2026.
    private static var containingAppBundle: Bundle {
        let appURL = Bundle.main.bundleURL
            .deletingLastPathComponent()    // PlugIns/
            .deletingLastPathComponent()    // <App>.app
        return Bundle(url: appURL) ?? .main
    }

    /// Ein Datenbankzugriff fuer die ganze Zeitleiste — Verbindung einmal
    /// oeffnen, alle Tage abfragen, wieder loslassen.
    private func loadEntries(days: Int) async -> [VerseEntry] {
        do {
            let database = try BibleDatabase(bundle: Self.containingAppBundle)
            let repository = BibleRepository(database: database)
            try await repository.load()
            let translations = await repository.translations
            let code = Localization.defaultTranslationCode(available: translations)
            guard let translation = translations.first(where: { $0.code == code })
                    ?? translations.first else { return [] }

            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: .now)
            var entries: [VerseEntry] = []
            for offset in 0..<days {
                guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                      let dayNumber = calendar.ordinality(of: .day, in: .era, for: day),
                      let verse = try await repository.randomCuratedVerse(
                          in: translation, seed: UInt64(dayNumber)),
                      let book = await repository.book(id: verse.reference.bookID) else { continue }
                entries.append(VerseEntry(
                    date: day,
                    reference: Localization.reference(verse.reference, book: book),
                    bookAbbrev: Localization.abbreviation(of: book),
                    chapterVerse: Localization.chapterVerse(
                        chapter: verse.reference.chapter,
                        verse: verse.reference.verse),
                    text: verse.text,
                    url: URL(string: "watchbible://verse/\(verse.reference.bookID)/\(verse.reference.chapter)/\(verse.reference.verse)")))
            }
            return entries
        } catch {
            return []
        }
    }
}

struct VerseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Nur die Referenz — mehr traegt die kleine Komplikation nicht.
            VStack(spacing: -1) {
                Text(verbatim: entry.bookAbbrev)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .widgetAccentable()
                Text(verbatim: entry.chapterVerse)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .minimumScaleFactor(0.7)
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: entry.reference)
                    .font(.system(size: 12, weight: .semibold))
                    .widgetAccentable()
                    .lineLimit(1)
                Text(verbatim: entry.text)
                    .font(.system(size: 12, design: .serif))
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
