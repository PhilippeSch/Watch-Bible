import SwiftUI

/// Themenliste. Aufbau wie die Buchwahl (Designspezifikation 4.3), nur ohne
/// Register: 26 Einträge erschliessen sich mit der Krone, 66 nicht mehr.
/// Je Zeile der Themenname links, die Anzahl Verse rechts in Monoschrift.
///
/// Inhalt und Reihenfolge kommen zur Laufzeit aus `curated`; ein Thema mehr in
/// der Datenbank ist eine Zeile mehr, ohne Codeänderung.
struct TopicListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Localization.sorted(model.topics)) { row($0) }
            }
            .padding(.horizontal, Layout.textInset)
        }
        .containerBackground(Color.ground, for: .navigation)
        .navigationTitle(Text("home.topics"))
    }

    private func row(_ topic: Topic) -> some View {
        NavigationLink(value: Route.topicVerses(key: topic.key)) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: Localization.name(of: topic))
                    .font(Typo.bookRow)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(verbatim: "\(topic.verseCount)")
                    .font(Typo.bookCount)
                    .foregroundStyle(Color.secondaryInk)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.rule).frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Die blosse Zahl rechts ist im Sehen eindeutig, vorgelesen nicht —
        // darum für VoiceOver die ausgeschriebene Form.
        .accessibilityLabel(Text(verbatim: Localization.name(of: topic)))
        // Int64: %lld des Katalogs liest 64 Bit, `Int` ist auf der Uhr 32 Bit.
        .accessibilityValue(Text(String.localizedStringWithFormat(
            String(localized: "count.verses"), Int64(topic.verseCount))))
    }
}
