import SwiftUI

/// Buchwahl (Designspezifikation 4.3): Liste in Abschnitten AT/NT, rechts das
/// Register mit sieben Sprungmarken. Register und Raster schliessen sich aus —
/// das Register ist der Buchwahl vorbehalten.
struct BookListView: View {
    @Environment(AppModel.self) private var model
    @State private var activeMark: Int = 1
    /// Kapitelzahl je Buch in der aktiven Uebersetzung. Leer, solange die
    /// Abfrage laeuft — dann bleibt die Zahl des Kanons stehen.
    @State private var chapterCounts: [Int: Int] = [:]

    /// Sieben Sprungmarken gemaess Spezifikation, als Buch-id:
    /// 1. Mose · Josua · Psalmen · Jesaja · Matthaeus · Roemer · Offenbarung.
    /// Beschriftet werden sie mit dem Buchkuerzel der Anzeigesprache aus der
    /// Datenbank («1Mo» · «Gen» · «Gn» · «創»), nicht aus dem String Catalog.
    private static let markBookIDs = [1, 6, 19, 23, 40, 45, 66]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    eyebrow("testament.old")
                    ForEach(model.books.filter { $0.testament == .at }) { row($0) }
                    eyebrow("testament.new")
                        .padding(.top, 10)
                    ForEach(model.books.filter { $0.testament == .nt }) { row($0) }
                }
                .padding(.leading, 4)
                .padding(.trailing, 36)   // Platz fuer das Register
            }
            .overlay(alignment: .trailing) { register(proxy) }
        }
        .containerBackground(Color.ground, for: .navigation)
        .navigationTitle(Text("lookup.books"))
        .task(id: model.settings.translationCode) {
            guard let repo = model.repository, let translation = model.translation else { return }
            chapterCounts = (try? await repo.chapterCounts(in: translation)) ?? [:]
        }
    }

    private func eyebrow(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(Typo.eyebrow)
            .kerning(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Color.secondaryInk)
            .padding(.bottom, 2)
    }

    private func row(_ book: Book) -> some View {
        NavigationLink(value: Route.chapters(bookID: book.id)) {
            HStack(alignment: .firstTextBaseline) {
                Text(Localization.name(of: book))
                    .font(Typo.bookRow)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                // Kapitelzahl der aktiven Uebersetzung, nie book.chapterCount
                // (Designspez. 4.5): dort steht das Maximum ueber alle
                // Uebersetzungen, und Joel und Maleachi weichen davon ab.
                Text(verbatim: "\(chapterCounts[book.id] ?? book.chapterCount)")
                    .font(Typo.bookCount)
                    .foregroundStyle(Color.secondaryInk)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 34)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.rule).frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(book.id)
    }

    private func markLabel(_ bookID: Int) -> String {
        guard let book = model.book(id: bookID) else { return "" }
        return Localization.abbreviation(of: book)
    }

    private func register(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 2) {
            ForEach(Self.markBookIDs, id: \.self) { bookID in
                let active = activeMark == bookID
                Button {
                    activeMark = bookID
                    withAnimation { proxy.scrollTo(bookID, anchor: .top) }
                } label: {
                    Text(verbatim: markLabel(bookID))
                        .font(Typo.register)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(active ? Color.ground : Color.secondaryInk)
                        .frame(width: 31)
                        .frame(maxHeight: .infinity)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 10,
                                                   bottomLeadingRadius: 10)
                                .fill(active ? Color.carmine : Color.fieldFill)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 2)
    }
}
