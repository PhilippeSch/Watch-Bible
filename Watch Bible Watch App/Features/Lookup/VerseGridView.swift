import SwiftUI

/// Verswahl (Designspezifikation 4.4): dreispaltiges Raster. Zellen jenseits
/// des Kapitelendes bleiben sichtbar, aber auf 32 % Deckkraft — die Grenze des
/// Kapitels wird begreifbar, statt nur zu fehlen. Ebenso Verse, die dieser
/// Uebersetzung mitten im Kapitel fehlen (BSB Mt 17,21, Klgl 2,1).
struct VerseGridView: View {
    @Environment(AppModel.self) private var model
    let bookID: Int
    let chapter: Int

    /// Die Versnummern, die es gibt. Nicht `1...verse_count`: der zaehlt die
    /// Verse, und in einem Kapitel mit Luecke endet das Kapitel dahinter.
    @State private var verses: Set<Int> = []

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Grid3.columns, spacing: Grid3.spacing) {
                ForEach(1...displayCount, id: \.self) { verse in
                    if verses.contains(verse) {
                        NavigationLink(value: Route.reader(bookID: bookID,
                                                           chapter: chapter,
                                                           verse: verse)) {
                            GridCell(number: verse)
                        }
                        .buttonStyle(.plain)
                    } else {
                        GridCell(number: verse, dimmed: true)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .safeAreaInset(edge: .bottom) { counter }
        .containerBackground(Color.ground, for: .navigation)
        .navigationTitle(title)
        .task(id: model.settings.translationCode) {
            guard let repo = model.repository, let translation = model.translation else { return }
            verses = Set((try? await repo.verseNumbers(book: bookID, chapter: chapter,
                                                       in: translation)) ?? [])
        }
    }

    /// Bis zum letzten vorhandenen Vers, dann auf volle Dreierreihen
    /// auffuellen; die ueberzaehligen Zellen sind blass.
    private var displayCount: Int {
        let last = verses.max() ?? 0
        return max(3, Int((Double(max(1, last)) / 3.0).rounded(.up)) * 3)
    }

    private var title: Text {
        guard let book = model.book(id: bookID) else { return Text(verbatim: "") }
        return Text(verbatim: Localization.chapterReference(book: book, chapter: chapter))
    }

    private var counter: some View {
        HStack {
            // Int64: %lld des Katalogs liest 64 Bit, `Int` ist auf der Uhr 32 Bit.
            Text(String.localizedStringWithFormat(String(localized: "count.verses"),
                                                  Int64(verses.count)))
            Spacer(minLength: 0)
            Text(verbatim: model.translation?.abbrev ?? "")
        }
        .font(Typo.counter)
        .foregroundStyle(Color.secondaryInk)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color.ground)
    }
}
