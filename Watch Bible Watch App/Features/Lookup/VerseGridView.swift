import SwiftUI

/// Verswahl (Designspezifikation 4.4): dreispaltiges Raster. Zellen jenseits
/// des Kapitelendes bleiben sichtbar, aber auf 32 % Deckkraft — die Grenze des
/// Kapitels wird begreifbar, statt nur zu fehlen.
struct VerseGridView: View {
    @Environment(AppModel.self) private var model
    let bookID: Int
    let chapter: Int

    @State private var verseCount = 0

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Grid3.columns, spacing: Grid3.spacing) {
                ForEach(1...displayCount, id: \.self) { verse in
                    if verse <= verseCount {
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
            verseCount = (try? await repo.verseCount(book: bookID, chapter: chapter,
                                                     in: translation)) ?? 0
        }
    }

    /// Auf volle Dreierreihen auffuellen; die ueberzaehligen Zellen sind blass.
    private var displayCount: Int {
        max(3, Int((Double(max(1, verseCount)) / 3.0).rounded(.up)) * 3)
    }

    private var title: Text {
        guard let book = model.book(id: bookID) else { return Text(verbatim: "") }
        return Text(verbatim: Localization.chapterReference(book: book, chapter: chapter))
    }

    private var counter: some View {
        HStack {
            Text(String.localizedStringWithFormat(String(localized: "count.verses"),
                                                  verseCount))
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
