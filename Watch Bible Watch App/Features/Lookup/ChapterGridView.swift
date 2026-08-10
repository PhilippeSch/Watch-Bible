import SwiftUI

/// Kapitelwahl (Designspezifikation 4.4): dreispaltiges Raster. Die Kapitel
/// kommen aus chapter_meta der aktiven Uebersetzung — nicht aus
/// book.chapter_count, denn Kapitelzahlen koennen sich unterscheiden (Joel 3/4).
struct ChapterGridView: View {
    @Environment(AppModel.self) private var model
    let bookID: Int

    @State private var chapters: [Int] = []

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Grid3.columns, spacing: Grid3.spacing) {
                ForEach(chapters, id: \.self) { chapter in
                    NavigationLink(value: Route.verses(bookID: bookID, chapter: chapter)) {
                        GridCell(number: chapter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
        .safeAreaInset(edge: .bottom) { counter }
        .containerBackground(Color.ground, for: .navigation)
        .navigationTitle(bookTitle)
        .task(id: model.settings.translationCode) {
            guard let repo = model.repository, let translation = model.translation else { return }
            let counts = (try? await repo.chapterVerseCounts(book: bookID, in: translation)) ?? [:]
            chapters = counts.keys.sorted()
        }
    }

    private var bookTitle: Text {
        guard let book = model.book(id: bookID) else { return Text(verbatim: "") }
        return Text(verbatim: Localization.name(of: book))
    }

    private var counter: some View {
        HStack {
            // Int64: %lld des Katalogs liest 64 Bit, `Int` ist auf der Uhr 32 Bit.
            Text(String.localizedStringWithFormat(String(localized: "count.chapters"),
                                                  Int64(chapters.count)))
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

/// Rasterzelle: 52 pt hoch, Feldflaeche, 14 pt gerundet, tabellarische Ziffern.
struct GridCell: View {
    let number: Int
    var dimmed = false
    var selected = false

    var body: some View {
        Text(verbatim: "\(number)")
            .font(Typo.gridDigit)
            .foregroundStyle(selected ? Color.ground : Color.ink)
            .frame(maxWidth: .infinity)
            .frame(height: Grid3.cellHeight)
            .background(
                RoundedRectangle(cornerRadius: Grid3.cornerRadius)
                    .fill(selected ? Color.carmine : Color.fieldFill)
            )
            .opacity(dimmed ? 0.32 : 1)
    }
}
