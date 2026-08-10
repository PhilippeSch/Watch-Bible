import SwiftUI

/// Zufallsvers (Designspezifikation 4.2): jede Seite ein Vers, Wischen nach
/// oben oder Tippen auf die Flaeche schaltet weiter. Die letzten 20 Verse
/// werden gemerkt und nicht sofort wiederholt.
struct RandomVerseView: View {
    @Environment(AppModel.self) private var model
    @State private var pages: [Page] = []
    @State private var selection = 0
    @State private var recentIDs: [Int] = []

    struct Page: Identifiable {
        let id = UUID()
        let verse: Verse
        let chapterVerseCount: Int
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                RandomVersePage(page: page) { advance() }
                    .tag(index)
            }
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: selection) {
            playAdvanceHaptic(model.settings)
            Task { await topUp() }
        }
        .task(id: "\(model.settings.translationCode)|\(model.settings.randomMode.rawValue)") {
            pages = []
            selection = 0
            await topUp()
        }
        .containerBackground(Color.ground, for: .navigation)
        .navigationTitle(Text("home.random"))
    }

    private func advance() {
        guard selection + 1 < pages.count else { return }
        withAnimation { selection += 1 }
    }

    /// Haelt immer zwei Seiten Vorlauf, damit Wischen und Tippen nie warten.
    private func topUp() async {
        guard let repo = model.repository, let translation = model.translation else { return }
        while pages.count < selection + 3 {
            let recent = Set(recentIDs)
            let verse: Verse?
            do {
                switch model.settings.randomMode {
                case .wholeBible:
                    verse = try await repo.randomVerse(in: translation, excluding: recent)
                case .curated:
                    verse = try await repo.randomCuratedVerse(in: translation, excluding: recent)
                }
                guard let verse else { return }
                let count = try await repo.verseCount(book: verse.reference.bookID,
                                                      chapter: verse.reference.chapter,
                                                      in: translation) ?? verse.reference.verse
                recentIDs.append(verse.id)
                if recentIDs.count > 20 { recentIDs.removeFirst() }
                pages.append(Page(verse: verse, chapterVerseCount: count))
            } catch {
                return
            }
        }
    }
}

private struct RandomVersePage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    let page: Page
    let onNext: () -> Void

    typealias Page = RandomVerseView.Page

    var body: some View {
        let verse = page.verse
        let scale = model.settings.textScale
        let language = model.translation?.language ?? "de"

        HStack(alignment: .top, spacing: 8) {
            Ribbon(position: 0,
                   extent: Double(verse.reference.verse) / Double(max(1, page.chapterVerseCount)))
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 6) {
                referenceLink(verse)
                ScrollView {
                    verseText(verse, scale: scale, language: language)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !luminanceReduced {
                    counterLine(verse)
                }
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 2)
        .contentShape(Rectangle())
        .onTapGesture { onNext() }
        .accessibilityAction(named: Text("random.next")) { onNext() }
    }

    private func referenceLink(_ verse: Verse) -> some View {
        // Tippen auf die Stellenangabe oeffnet die Leseansicht am selben Vers.
        NavigationLink(value: Route.reader(bookID: verse.reference.bookID,
                                           chapter: verse.reference.chapter,
                                           verse: verse.reference.verse)) {
            Text(referenceString(verse))
                .font(Typo.reference)
                .kerning(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.carmine)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .buttonStyle(.plain)
    }

    private func verseText(_ verse: Verse, scale: AppSettings.TextScale,
                           language: String) -> some View {
        (Text("\(verse.reference.verse)")
            .font(Typo.verseNumber(scale: scale))
            .baselineOffset(Typo.verseNumberOffset(scale: scale))
            .foregroundStyle(Color.carmine)
         + Text(verbatim: "\u{2009}")
         + Text(verbatim: luminanceReduced ? shortened(verse.text) : verse.text)
            .font(Typo.verse(scale: scale, language: language))
            .foregroundStyle(Color.ink))
        .lineSpacing(Typo.verseLineSpacing(scale: scale, language: language))
    }

    /// Always-On: Verstext auf die ersten Zeilen kuerzen (Designspez. 1).
    private func shortened(_ text: String) -> String {
        guard text.count > 120 else { return text }
        return String(text.prefix(110)) + "…"
    }

    private func counterLine(_ verse: Verse) -> some View {
        // Laufende Nummer innerhalb der Uebersetzung: verse.id ist lueckenlos,
        // beginnt aber erst bei first_verse_id — daher die Normierung.
        let translation = model.translation
        let ordinal = verse.id - (translation?.firstVerseID ?? 1) + 1
        let total = translation?.verseCount ?? 0
        return HStack {
            Text(verbatim: Localization.position(ordinal, of: total))
            Spacer(minLength: 0)
            Text(verbatim: translation?.abbrev ?? "")
        }
        .font(Typo.counter)
        .foregroundStyle(Color.secondaryInk)
        .accessibilityLabel(Text(verbatim: Localization.positionAccessibility(ordinal, of: total)))
    }

    private func referenceString(_ verse: Verse) -> String {
        guard let book = model.book(id: verse.reference.bookID) else {
            return verse.displayReference
        }
        return Localization.reference(verse.reference, book: book)
    }
}
