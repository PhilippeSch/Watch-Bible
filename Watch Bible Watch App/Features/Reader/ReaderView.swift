import SwiftUI

/// Leseansicht (Designspezifikation 4.5): das ganze Kapitel als Fliesstext mit
/// hochgestellten Verszahlen, wie im Druck. Der gewaehlte Vers in voller
/// Deckkraft, die uebrigen auf 70 %. Die Krone scrollt, das Baendchen laeuft mit.
///
/// Uebersetzungswechsel geht ueber `BibleRepository.resolve`; jeder Fall ausser
/// `.exact` wird sichtbar gemacht (4.6) — wer das wegvereinfacht, zeigt ohne
/// Warnung den falschen Bibeltext.
struct ReaderView: View {
    @Environment(AppModel.self) private var model
    let highlight: Int?

    /// Stelle veraenderlich: das Weiterblaettern tauscht sie aus, statt eine
    /// weitere Ansicht auf den NavigationStack zu legen — sonst wuechse der
    /// Stapel mit jedem gelesenen Kapitel, und die Ruecktaste fuehrte durch
    /// jedes einzelne zurueck.
    @State private var bookID: Int
    @State private var chapter: Int

    @State private var verses: [Verse] = []
    @State private var currentHighlight: Int?
    @State private var switchInfo: SwitchInfo?
    @State private var unavailableIn: String?
    @State private var showTranslationPicker = false
    @State private var scrollFraction: Double = 0
    @State private var viewportFraction: Double = 1
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var didAutoScroll = false
    @State private var scrollPosition = ScrollPosition()

    /// Solange wahr, stehen die uebrigen Verse auf 70 %. Faellt beim ersten
    /// Scrollen auf falsch und bleibt es: die Hervorhebung zeigt beim Ankommen,
    /// wo man gelandet ist, und tritt dann beiseite — wer weiterliest, soll
    /// nirgends auf blasse Schrift stossen.
    @State private var dimOthers = false
    /// Ruhelage nach dem automatischen Hinscrollen, **beobachtet statt
    /// berechnet**: `scrollTo(y:)` und `onScrollGeometryChange` messen nicht
    /// dasselbe (die Geometrie rechnet `contentInsets.top` hinzu). Ein
    /// Vergleich gegen den Zielwert waere darum je nach Einfassung sofort
    /// ausgeloest worden. `nil` heisst: noch nicht zur Ruhe gekommen.
    @State private var restOffset: CGFloat?
    @State private var lastOffset: CGFloat = 0

    /// Wie weit gescrollt sein muss, damit es als Absicht gilt — etwa eine
    /// Zeile. Ein Streifen beim Antippen soll die Hervorhebung nicht loeschen.
    private static let scrollIntentThreshold: CGFloat = 12

    /// Abweichungsfall nach einem Uebersetzungswechsel (Designspez. 4.6).
    struct SwitchInfo {
        let sourceName: String
        let sourceVerseCount: Int
        let targetName: String
        let targetVerseCount: Int
        let clampedRequested: Int?
    }

    /// Nachbarkapitel in der aktiven Uebersetzung, Buchgrenzen eingeschlossen.
    /// `nil` heisst Kanonende — vor 1Mo 1 und nach Offb 22 gibt es nichts.
    /// Bestimmt wird beides in `BibleRepository.adjacentChapter`.
    @State private var previousStep: ChapterReference?
    @State private var nextStep: ChapterReference?

    init(bookID: Int, chapter: Int, highlight: Int?) {
        self.highlight = highlight
        _bookID = State(initialValue: bookID)
        _chapter = State(initialValue: chapter)
        _currentHighlight = State(initialValue: highlight)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Ribbon(position: scrollFraction * (1 - viewportFraction),
                   extent: viewportFraction)
                .padding(.vertical, 2)
            scroll
        }
        .padding(.leading, 6)
        .padding(.trailing, 2)
        .containerBackground(Color.ground, for: .navigation)
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showTranslationPicker = true
                } label: {
                    Text(verbatim: model.translation?.abbrev ?? "")
                        .font(Typo.register)
                }
                .accessibilityLabel(Text("reader.changeTranslation"))
            }
        }
        .sheet(isPresented: $showTranslationPicker) {
            // Ein Blatt bekommt keinen `containerBackground`; ohne eigenen
            // Grund stuende die Abschnittsueberschrift auf dem grauen
            // Systemblatt statt auf Papier.
            TranslationListView(selectedCode: model.settings.translationCode) { code in
                showTranslationPicker = false
                Task { await switchTranslation(to: code) }
            }
            .background(Color.ground.ignoresSafeArea())
        }
        .alert(Text("divergence.unavailable \(unavailableIn ?? "")"),
               isPresented: Binding(get: { unavailableIn != nil },
                                    set: { if !$0 { unavailableIn = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .task(id: ChapterReference(bookID: bookID, chapter: chapter)) { await load() }
    }

    private var scroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Der Abweichungsfall steht direkt unter dem aufgeloesten Vers
                // (Designspez. 4.6) — beim Klemmen ans Kapitelende ist er damit
                // ohne Scrollen sichtbar.
                if let info = switchInfo {
                    let split = currentHighlight ?? Int.max
                    flowText(verses.filter { $0.reference.verse <= split })
                    DivergenceTable(info: info)
                    flowText(verses.filter { $0.reference.verse > split })
                } else {
                    flowText(verses)
                }
                chapterFooter
            }
            .padding(.bottom, 12)
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear { contentHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, h in
                            contentHeight = h
                            autoScrollIfNeeded()
                        }
                }
            )
        }
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: ScrollFractions.self, of: { geo in
            ScrollFractions(
                offset: geo.contentOffset.y + geo.contentInsets.top,
                content: geo.contentSize.height,
                container: geo.containerSize.height
            )
        }, action: { _, new in
            viewportHeight = new.container
            viewportFraction = new.content > 0
                ? min(1, new.container / new.content) : 1
            let scrollable = max(1, new.content - new.container)
            scrollFraction = min(1, max(0, new.offset / scrollable))
            lastOffset = new.offset
            if dimOthers, let rest = restOffset,
               abs(new.offset - rest) > Self.scrollIntentThreshold {
                dimOthers = false
            }
        })
    }

    private struct ScrollFractions: Equatable {
        var offset: CGFloat
        var content: CGFloat
        var container: CGFloat
    }

    private var title: Text {
        guard let book = model.book(id: bookID) else { return Text(verbatim: "") }
        return Text(verbatim: Localization.chapterReference(book: book, chapter: chapter))
    }

    // MARK: - Fliesstext

    @ViewBuilder
    private func flowText(_ subset: [Verse]) -> some View {
        if !subset.isEmpty {
            let scale = model.settings.textScale
            let language = model.translation?.language ?? "de"
            subset.reduce(Text(verbatim: "")) { flow, verse in
                let dim = dimOthers && verse.reference.verse != currentHighlight
                return flow
                    + Text("\(verse.reference.verse)")
                        .font(Typo.verseNumber(scale: scale))
                        .baselineOffset(Typo.verseNumberOffset(scale: scale))
                        .foregroundStyle(Color.carmine.opacity(dim ? 0.7 : 1))
                    + Text(verbatim: "\u{2009}")
                    + Text(verbatim: verse.text + " ")
                        .font(Typo.verse(scale: scale, language: language))
                        .foregroundStyle(Color.ink.opacity(dim ? 0.7 : 1))
            }
            .lineSpacing(Typo.verseLineSpacing(scale: scale, language: language))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Weiterblaettern

    /// Zwei Knoepfe am Ende des Kapitels, beschriftet mit dem Ziel. Wischen
    /// quer waere auf watchOS die Ruecknavigation, und die Krone scrollt
    /// bereits — der Leser kommt hier ohnehin an, wenn er zu Ende gelesen hat.
    @ViewBuilder
    private var chapterFooter: some View {
        if previousStep != nil || nextStep != nil {
            HStack(spacing: 6) {
                stepButton(previousStep, forward: false)
                stepButton(nextStep, forward: true)
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func stepButton(_ step: ChapterReference?, forward: Bool) -> some View {
        if let step, let book = model.book(id: step.bookID) {
            Button {
                go(to: step)
            } label: {
                HStack(spacing: 2) {
                    if !forward { Image(systemName: "chevron.backward") }
                    Text(verbatim: "\(Localization.abbreviation(of: book)) \(step.chapter)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if forward { Image(systemName: "chevron.forward") }
                }
                .font(Typo.bookRow)
                .foregroundStyle(Color.carmine)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: Grid3.cornerRadius)
                        .fill(Color.fieldFill)
                )
            }
            .buttonStyle(.plain)
            // Vorgelesen ist «Mt 6» nichtssagend — hier der volle Name.
            .accessibilityLabel(Text(verbatim:
                Localization.chapterReference(book: book, chapter: step.chapter)))
        } else {
            // Kanonende: die Haelfte bleibt leer, damit der verbleibende Knopf
            // nicht ueber die ganze Breite springt und die Seite ruhig bleibt.
            Color.clear.frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func go(to step: ChapterReference) {
        playAdvanceHaptic(model.settings)
        // Ein neues Kapitel beginnt oben und ohne hervorgehobenen Vers; der
        // Abweichungsfall galt fuer das alte und wird mit ihm ungueltig.
        currentHighlight = nil
        switchInfo = nil
        didAutoScroll = true
        verses = []
        scrollPosition.scrollTo(y: 0)
        bookID = step.bookID
        chapter = step.chapter
    }

    // MARK: - Laden und Wechsel

    private func load() async {
        guard let repo = model.repository, let translation = model.translation else { return }
        // Vor dem ersten `await` setzen, sonst zeichnet SwiftUI den Text
        // dazwischen einmal ungedimmt und er blitzt auf.
        dimOthers = currentHighlight != nil
        restOffset = nil
        verses = (try? await repo.chapter(book: bookID, chapter: chapter,
                                          in: translation)) ?? []
        previousStep = try? await repo.adjacentChapter(book: bookID, chapter: chapter,
                                                       offset: -1, in: translation)
        nextStep = try? await repo.adjacentChapter(book: bookID, chapter: chapter,
                                                    offset: +1, in: translation)
        rememberPosition()
        autoScrollIfNeeded()

        // Dem automatischen Hinscrollen Zeit lassen, dann die erreichte
        // Position als Ruhelage merken. Erst ab hier gilt eine Aenderung als
        // Scrollen des Lesers. Laeuft in `.task(id:)` — ein Kapitelwechsel
        // bricht das Warten ab, bevor eine falsche Ruhelage entsteht.
        guard dimOthers else { return }
        do {
            try await Task.sleep(for: .milliseconds(500))
        } catch {
            return          // Kapitelwechsel: keine Ruhelage aus dem alten setzen
        }
        restOffset = lastOffset
    }

    private func rememberPosition() {
        model.settings.lastReference = VerseReference(bookID: bookID, chapter: chapter,
                                                      verse: currentHighlight ?? 1)
    }

    /// Ein Fliesstext hat keine Ankerpunkte je Vers; die Zielposition wird
    /// deshalb ueber den Zeichenanteil vor dem gewaehlten Vers geschaetzt.
    private func autoScrollIfNeeded() {
        guard !didAutoScroll, let target = currentHighlight, !verses.isEmpty,
              contentHeight > viewportHeight, viewportHeight > 0 else { return }
        let before = verses.filter { $0.reference.verse < target }
            .reduce(0) { $0 + $1.text.count }
        let total = max(1, verses.reduce(0) { $0 + $1.text.count })
        let fraction = Double(before) / Double(total)
        let y = max(0, fraction * contentHeight - viewportHeight * 0.25)
        didAutoScroll = true
        scrollPosition.scrollTo(y: min(y, contentHeight - viewportHeight))
    }

    private func switchTranslation(to code: String) async {
        guard let repo = model.repository,
              let source = model.translation,
              let target = model.translations.first(where: { $0.code == code }),
              target.id != source.id else { return }
        let ref = VerseReference(bookID: bookID, chapter: chapter,
                                 verse: currentHighlight ?? 1)
        do {
            let resolution = try await repo.resolve(ref, from: source, to: target)
            let sourceCount = try await repo.verseCount(book: bookID, chapter: chapter,
                                                        in: source) ?? 0
            let targetCount = try await repo.verseCount(book: bookID, chapter: chapter,
                                                        in: target) ?? 0
            switch resolution {
            case .unavailable:
                // Zieluebersetzung hat dieses Kapitel nicht: Wechsel abbrechen,
                // sichtbar melden, bei der bisherigen Uebersetzung bleiben.
                unavailableIn = target.name
                return
            case .exact:
                switchInfo = nil
            case .divergent:
                switchInfo = SwitchInfo(sourceName: source.name,
                                        sourceVerseCount: sourceCount,
                                        targetName: target.name,
                                        targetVerseCount: targetCount,
                                        clampedRequested: nil)
            case .clamped(let verse, let requested):
                switchInfo = SwitchInfo(sourceName: source.name,
                                        sourceVerseCount: sourceCount,
                                        targetName: target.name,
                                        targetVerseCount: targetCount,
                                        clampedRequested: requested)
                currentHighlight = verse.reference.verse
            }
            model.settings.translationCode = target.code
            didAutoScroll = false
            await load()
        } catch {
            // Fehler beim Wechsel: bisherige Ansicht bleibt bestehen.
        }
    }
}

/// Zweizeilige Tabelle des Abweichungsfalls (Designspez. 4.6): zwei Zahlen
/// erklaeren den Sachverhalt vollstaendig — keine Signalfarbe, kein Symbol,
/// nichts zum Wegklicken.
private struct DivergenceTable: View {
    let info: ReaderView.SwitchInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(name: info.sourceName, count: info.sourceVerseCount)
            row(name: info.targetName, count: info.targetVerseCount)
            if let requested = info.clampedRequested {
                HStack(alignment: .top, spacing: 8) {
                    Rectangle().fill(Color.carmine).frame(width: 3)
                    Text("divergence.clamped \(requested)")
                        .font(Typo.tableRow)
                        .foregroundStyle(Color.ink)
                }
                .padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Color.rule).frame(height: 0.5) }
    }

    private func row(name: String, count: Int) -> some View {
        HStack {
            Text(verbatim: name)
                .foregroundStyle(Color.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            // Int64: %lld des Katalogs liest 64 Bit, `Int` ist auf der Uhr 32 Bit.
            Text(verbatim: String.localizedStringWithFormat(
                String(localized: "count.verses"), Int64(count)))
                .monospacedDigit()
                .foregroundStyle(Color.ink)
        }
        .font(Typo.tableRow)
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.rule).frame(height: 0.5) }
    }
}
