import SwiftUI

/// Einstellungen (Designspezifikation 4.7): Uebersetzung · Zufallsmodus ·
/// Darstellung · Schriftgroesse · Haptik · Impressum.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        List {
            NavigationLink(value: Route.translationPicker) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.translation")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryInk)
                    Text(verbatim: model.translation?.name ?? "")
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .listRowBackground(rowBackground)

            Picker(selection: $settings.randomMode) {
                ForEach(AppSettings.RandomMode.allCases) { mode in
                    Text(verbatim: mode.label).tag(mode)
                }
            } label: {
                Text("settings.randomMode").foregroundStyle(Color.ink)
            }
            .listRowBackground(rowBackground)

            Picker(selection: $settings.appearance) {
                ForEach(AppSettings.Appearance.allCases) { appearance in
                    Text(verbatim: appearance.label).tag(appearance)
                }
            } label: {
                Text("settings.appearance").foregroundStyle(Color.ink)
            }
            .listRowBackground(rowBackground)

            if settings.appearance == .auto {
                nightTimePicker(label: "settings.night.from",
                                selection: $settings.nightStartMinutes)
                nightTimePicker(label: "settings.night.until",
                                selection: $settings.nightEndMinutes)
            }

            Picker(selection: $settings.textScale) {
                ForEach(AppSettings.TextScale.allCases) { scale in
                    Text(verbatim: scale.label).tag(scale)
                }
            } label: {
                Text("settings.textSize").foregroundStyle(Color.ink)
            }
            .listRowBackground(rowBackground)

            Toggle(isOn: $settings.hapticsEnabled) {
                Text("settings.haptics").foregroundStyle(Color.ink)
            }
            .listRowBackground(rowBackground)

            NavigationLink(value: Route.about) {
                Text("settings.about")
            }
            .listRowBackground(rowBackground)
        }
        .foregroundStyle(Color.ink)
        .containerBackground(Color.ground, for: .navigation)
        .navigationTitle(Text("home.settings"))
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: Grid3.cornerRadius).fill(Color.fieldFill)
    }

    /// Uhrzeitwahl in halben Stunden — watchOS hat keinen DatePicker, und
    /// feiner als 30 Minuten muss ein Nachtfenster nicht sein.
    private func nightTimePicker(label: LocalizedStringKey,
                                 selection: Binding<Int>) -> some View {
        Picker(selection: selection) {
            ForEach(Array(stride(from: 0, to: 24 * 60, by: 30)), id: \.self) { minutes in
                Text(verbatim: Self.timeLabel(minutes: minutes)).tag(minutes)
            }
        } label: {
            Text(label).foregroundStyle(Color.ink)
        }
        .listRowBackground(rowBackground)
    }

    private static func timeLabel(minutes: Int) -> String {
        var parts = DateComponents()
        parts.hour = minutes / 60
        parts.minute = minutes % 60
        let date = Calendar.current.date(from: parts) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// Uebersetzungswahl in den Einstellungen, nach Sprache gruppiert.
struct TranslationPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TranslationListView(selectedCode: model.settings.translationCode) { code in
            model.settings.translationCode = code
            dismiss()
        }
        .containerBackground(Color.ground, for: .navigation)
        .navigationTitle(Text("settings.translation"))
    }
}

/// Gemeinsame Liste aller Uebersetzungen (Einstellungen und Leseansicht).
/// Inhalt kommt vollstaendig aus der Datenbank — nichts ist hartkodiert.
struct TranslationListView: View {
    @Environment(AppModel.self) private var model
    let selectedCode: String
    let onSelect: (String) -> Void

    var body: some View {
        List {
            ForEach(languages, id: \.self) { language in
                Section {
                    ForEach(model.translations.filter { $0.language == language }) { translation in
                        Button {
                            onSelect(translation.code)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(verbatim: translation.name)
                                        .foregroundStyle(Color.ink)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.7)
                                    Text(verbatim: translation.abbrev)
                                        .font(Typo.bookCount)
                                        .foregroundStyle(Color.secondaryInk)
                                }
                                Spacer(minLength: 0)
                                if translation.code == selectedCode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.carmine)
                                }
                            }
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: Grid3.cornerRadius)
                                .fill(Color.fieldFill)
                        )
                    }
                } header: {
                    Text(languageLabel(language))
                        .font(Typo.sectionHeader)
                        .foregroundStyle(Color.secondaryInk)
                }
            }
        }
    }

    /// Anzeigesprache zuoberst, danach die übrigen in Datenbankreihenfolge.
    private var languages: [String] {
        Localization.languageOrder(of: model.translations)
    }

    /// Dynamischer Schluessel — String(localized:) wuerde die Interpolation
    /// als Formatargument lesen und den Schluessel nie finden.
    private func languageLabel(_ code: String) -> String {
        Bundle.main.localizedString(forKey: "language.\(code)", value: code, table: nil)
    }
}
