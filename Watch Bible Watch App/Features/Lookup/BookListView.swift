import SwiftUI

/// Buchwahl (Designspezifikation 4.3): Liste in Abschnitten AT/NT, rechts das
/// Register mit sieben Sprungmarken. Register und Raster schliessen sich aus —
/// das Register ist der Buchwahl vorbehalten.
struct BookListView: View {
    @Environment(AppModel.self) private var model
    @State private var activeMark: String = "1Mo"

    /// Sieben Sprungmarken gemaess Spezifikation: 1Mo · Jos · Ps · Jes · Mt · Rom · Offb.
    private static let marks: [(code: String, bookID: Int)] = [
        ("1Mo", 1), ("Jos", 6), ("Ps", 19), ("Jes", 23),
        ("Mt", 40), ("Rom", 45), ("Offb", 66)
    ]

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
                Text(verbatim: "\(book.chapterCount)")
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

    private func register(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 2) {
            ForEach(Self.marks, id: \.code) { mark in
                Button {
                    activeMark = mark.code
                    withAnimation { proxy.scrollTo(mark.bookID, anchor: .top) }
                } label: {
                    Text(verbatim: mark.code)
                        .font(Typo.register)
                        .foregroundStyle(activeMark == mark.code ? Color.ground : Color.secondaryInk)
                        .frame(width: 31)
                        .frame(maxHeight: .infinity)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 10,
                                                   bottomLeadingRadius: 10)
                                .fill(activeMark == mark.code ? Color.carmine : Color.fieldFill)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 2)
    }
}
