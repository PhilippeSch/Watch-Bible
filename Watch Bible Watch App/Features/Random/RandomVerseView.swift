import SwiftUI

/// Zufallsvers (Designspezifikation 4.2): jede Seite ein Vers, Wischen nach
/// oben oder Tippen auf die Flaeche schaltet weiter. Die letzten 20 Verse
/// werden gemerkt und nicht sofort wiederholt.
///
/// Mit `topic` bleibt dieselbe Ansicht auf ein Thema beschraenkt: gezogen wird
/// dann nur aus dessen Stellen, der Zufallsmodus der Einstellungen gilt dort
/// nicht. Alles uebrige — Wischen, «Naechster», Haptik, Wiederholungssperre —
/// ist dasselbe; darum eine Ansicht und keine zweite daneben.
struct RandomVerseView: View {
    @Environment(AppModel.self) private var model
    /// nil = Zufallsvers ueber die ganze Bibel bzw. das ganze Register,
    /// je nach Einstellung.
    let topic: Topic?
    @State private var pages: [Page] = []
    @State private var selection = 0
    @State private var recentIDs: [Int] = []
    /// Sperre im Themenmodus: dort wird ueber die Stelle gemerkt, nicht ueber
    /// `verse.id` — dieselbe Stelle hat je Uebersetzung eine andere id.
    @State private var recentReferences: [VerseReference] = []

    init(topic: Topic? = nil) {
        self.topic = topic
    }

    /// Wie viele Verse zurueck gesperrt wird. Ueber die ganze Bibel sind es die
    /// 20 der Designspezifikation; ein Thema mit 10 Versen kann keine 20 sperren, sonst
    /// bliebe nichts zu ziehen. Die Haelfte der Liste haelt Wiederholungen weit
    /// genug auseinander und laesst die Auswahl trotzdem zufaellig — eine Sperre
    /// von n−1 machte aus der Ziehung eine feste Reihenfolge.
    private var recentLimit: Int {
        guard let topic else { return 20 }
        return min(20, max(1, topic.verseCount / 2))
    }

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
        .task(id: "\(model.settings.translationCode)|\(model.settings.randomMode.rawValue)|\(topic?.key ?? "")") {
            pages = []
            selection = 0
            await topUp()
        }
        .containerBackground(Color.ground, for: .navigation)
        .navigationTitle(title)
    }

    /// Im Themenmodus traegt der Bildschirmtitel das Thema — sonst waere nach
    /// zwei Wischern nicht mehr erkennbar, worin man blaettert.
    private var title: Text {
        guard let topic else { return Text("home.random") }
        return Text(verbatim: Localization.name(of: topic))
    }

    private func advance() {
        guard selection + 1 < pages.count else { return }
        withAnimation { selection += 1 }
    }

    /// Haelt immer zwei Seiten Vorlauf, damit Wischen und Tippen nie warten.
    private func topUp() async {
        guard let repo = model.repository, let translation = model.translation else { return }
        while pages.count < selection + 3 {
            let verse: Verse?
            do {
                if let topic {
                    verse = try await repo.randomCuratedVerse(
                        in: translation, topic: topic.key,
                        excluding: Set(recentReferences))
                } else {
                    let recent = Set(recentIDs)
                    switch model.settings.randomMode {
                    case .wholeBible:
                        verse = try await repo.randomVerse(in: translation, excluding: recent)
                    case .curated:
                        verse = try await repo.randomCuratedVerse(in: translation, excluding: recent)
                    }
                }
                guard let verse else { return }
                let count = try await repo.verseCount(book: verse.reference.bookID,
                                                      chapter: verse.reference.chapter,
                                                      in: translation) ?? verse.reference.verse
                remember(verse)
                pages.append(Page(verse: verse, chapterVerseCount: count))
            } catch {
                return
            }
        }
    }

    private func remember(_ verse: Verse) {
        recentIDs.append(verse.id)
        if recentIDs.count > recentLimit { recentIDs.removeFirst() }
        recentReferences.append(verse.reference)
        if recentReferences.count > recentLimit { recentReferences.removeFirst() }
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
