import Foundation

/// Alles, was von der Anzeigesprache abhängt — und nur davon.
///
/// Grundregel: die Sprache bestimmt **Vorgaben**, nie eine getroffene Wahl.
/// Wer einmal eine Übersetzung ausgewählt hat, behält sie, auch wenn er später
/// die Systemsprache wechselt.
enum Localization {

    /// Die Sprachen, in denen die Oberfläche vorliegt — je eine Sprache, für
    /// die auch eine Bibelübersetzung mitgeliefert wird. Geschrieben wie
    /// `translation.language` in der Datenbank, damit Anzeigesprache und
    /// Übersetzungssprache ohne Umrechnung vergleichbar sind.
    static let supportedLanguages = ["de", "en", "es", "fr", "it", "pt",
                                     "zh-Hant", "zh-Hans"]

    /// Rückfall, wenn das System eine Sprache meldet, für die es keine
    /// Übersetzung gibt.
    static let fallbackLanguage = "en"

    /// Die aktive Anzeigesprache der App, nicht die des Systems: `preferredLocalizations`
    /// liefert die Sprache, für die das Bundle tatsächlich Texte hat.
    ///
    /// **Nicht auf zwei Zeichen kürzen.** Chinesisch unterscheidet sich in der
    /// Schrift, nicht in der Sprache: «zh» allein trifft weder `zh-Hant` noch
    /// `zh-Hans` und ließe beide chinesischen Übersetzungen ins Leere laufen.
    static var displayLanguage: String {
        guard let preferred = Bundle.main.preferredLocalizations.first else {
            return fallbackLanguage
        }
        return normalized(preferred)
    }

    /// Bildet eine Sprachkennung des Systems auf die Schreibweise der
    /// Datenbank ab: «de-CH» → «de», «zh-TW» → «zh-Hant», «zh» → «zh-Hans».
    static func normalized(_ identifier: String) -> String {
        if supportedLanguages.contains(identifier) { return identifier }
        let language = Locale.Language(identifier: identifier)
        guard let code = language.languageCode?.identifier else { return fallbackLanguage }
        if code == "zh" {
            // Ohne Schriftangabe («zh», «zh-CN») ergänzt maximalIdentifier sie.
            let script = language.script?.identifier
                ?? Locale.Language(identifier: language.maximalIdentifier).script?.identifier
            return script == "Hant" ? "zh-Hant" : "zh-Hans"
        }
        return supportedLanguages.contains(code) ? code : fallbackLanguage
    }

    /// Vorgabe für die Bibelübersetzung beim allerersten Start: die **erste
    /// Übersetzung der Anzeigesprache in der Reihenfolge der Datenbank**.
    /// `available` kommt bereits nach `sort_order` sortiert aus dem Repository,
    /// also genau in der Reihenfolge, in der die App sie auch anbietet.
    ///
    /// Nichts davon ist fest verdrahtet: fällt eine Übersetzung aus der
    /// Datenbank weg, rückt die nächste derselben Sprache nach.
    static func defaultTranslationCode(available: [Translation]) -> String {
        defaultTranslationCode(available: available, language: displayLanguage)
    }

    /// Wie oben, aber mit ausdrücklicher Sprache — so ist die Regel prüfbar,
    /// ohne das Bundle umzustellen.
    static func defaultTranslationCode(available: [Translation],
                                       language: String) -> String {
        if let match = available.first(where: { $0.language == language }) {
            return match.code
        }
        // Chinesisch: notfalls die andere Schriftvariante — verständlicher
        // als eine fremde Sprache.
        if language.hasPrefix("zh"),
           let chinese = available.first(where: { $0.language.hasPrefix("zh") }) {
            return chinese.code
        }
        // Sonst Englisch als Verkehrssprache, zuletzt die erste überhaupt.
        return available.first(where: { $0.language == fallbackLanguage })?.code
            ?? available.first?.code ?? ""
    }

    /// Die Übersetzung, mit der die App startet.
    ///
    /// Eine **ausdrücklich gewählte** Übersetzung bleibt, auch wenn die
    /// Anzeigesprache später wechselt — das ist die Zusage der Einstellungen.
    /// Eine bloss **vorgegebene** folgt der Sprache: wer die Uhr auf
    /// Portugiesisch einrichtet, nie eine Übersetzung wählt und später auf
    /// Deutsch wechselt, soll nicht weiter eine portugiesische Bibel lesen.
    ///
    /// Kennt die Datenbank den gewählten Code nicht mehr, greift ebenfalls die
    /// Sprachvorgabe — ohne die gespeicherte Wahl zu löschen.
    static func startupTranslationCode(stored: String,
                                       pickedByUser: Bool,
                                       available: [Translation],
                                       language: String = displayLanguage) -> String {
        if pickedByUser, available.contains(where: { $0.code == stored }) {
            return stored
        }
        return defaultTranslationCode(available: available, language: language)
    }

    /// Sprachen für die Übersetzungswahl: die Anzeigesprache zuoberst, danach
    /// die übrigen in der Reihenfolge der Datenbank.
    static func languageOrder(of translations: [Translation]) -> [String] {
        languageOrder(of: translations, first: displayLanguage)
    }

    static func languageOrder(of translations: [Translation],
                              first language: String) -> [String] {
        var seen: Set<String> = []
        let all = translations.map(\.language).filter { seen.insert($0).inserted }
        guard all.contains(language) else { return all }
        return [language] + all.filter { $0 != language }
    }

    /// Buchname in der Anzeigesprache. Alle sechs Spalten sind für alle
    /// 66 Bücher gefüllt; fehlt eine, bleibt der deutsche Name stehen.
    static func name(of book: Book) -> String {
        name(of: book, in: displayLanguage)
    }

    static func name(of book: Book, in language: String) -> String {
        book.names[language] ?? book.name
    }

    /// Buchkürzel in der Anzeigesprache — für das Register der Buchliste und
    /// die runde Komplikation, wo der volle Name nicht hinpasst. Je Sprache
    /// der dort übliche Satz: «1Mo» · «Gen» · «Gn» · «創».
    ///
    /// Rückfall ist `book.code`. Der ist deutsch geprägt und damit nicht
    /// richtig, aber kurz — besser als eine leere Sprungmarke.
    static func abbreviation(of book: Book) -> String {
        abbreviation(of: book, in: displayLanguage)
    }

    static func abbreviation(of book: Book, in language: String) -> String {
        book.abbreviations[language] ?? book.code
    }

    /// Themenname in der Anzeigesprache, aus dem String Catalog
    /// («topic.Wort Gottes»). Anders als Buchnamen, die an die Rechtschreibung
    /// der Übersetzung gebunden sind, ist ein Themenname blosse Beschriftung —
    /// er gehört darum in den Katalog. Die Datenbank sagt nur, welche Themen es
    /// gibt.
    ///
    /// Der Schlüssel wird zur Laufzeit gebildet und ist deshalb für Xcode nicht
    /// auffindbar; die Einträge sind im Katalog als `manual` geführt und dürfen
    /// nicht als «unbenutzt» entfernt werden. Fehlt einer, gibt der Katalog den
    /// Schlüssel selbst zurück — dann steht dort der deutsche Wert, und der
    /// Unit-Test `themenSindInAllenSprachenUebersetzt` schlägt fehl.
    static func name(of topic: Topic) -> String {
        let localized = String(localized: String.LocalizationValue(topic.localizationKey))
        return localized == topic.localizationKey ? topic.key : localized
    }

    /// Themen in der Reihenfolge der Anzeigesprache sortiert — «Amour» steht
    /// im Französischen vorn, «Liebe» im Deutschen in der Mitte. Die Datenbank
    /// liefert sie nach dem deutschen Schlüssel; das wäre in fünf von sechs
    /// Sprachen keine Ordnung.
    static func sorted(_ topics: [Topic]) -> [Topic] {
        topics.sorted {
            name(of: $0).localizedStandardCompare(name(of: $1)) == .orderedAscending
        }
    }

    /// Stellenangabe. Der Trenner ist **nicht** kosmetisch: deutsche Bibeln
    /// schreiben «Johannes 3,16», englische «John 3:16». Darum über den
    /// String Catalog, nicht als fest verdrahtetes Zeichen.
    static func reference(_ ref: VerseReference, book: Book) -> String {
        String(localized: "reference.format %1$@ %2$lld %3$lld",
               defaultValue: "\(name(of: book)) \(ref.chapter),\(ref.verse)")
            .replacingOccurrences(of: "%1$@", with: name(of: book))
            .replacingOccurrences(of: "%2$lld", with: String(ref.chapter))
            .replacingOccurrences(of: "%3$lld", with: String(ref.verse))
    }

    /// Copyright-Zeile einer Übersetzung im Impressum, in der Anzeigesprache.
    ///
    /// Dieselbe Arbeitsteilung wie bei den Themen: die **Datenbank sagt, welche
    /// Übersetzungen es gibt**, der **Katalog, wie ihre Zeile geschrieben
    /// wird** — unter `copyright.<translation.code>`. Der Code ist der stabile
    /// Schlüssel; die `id` verschiebt sich, sobald die Datenbank neu erzeugt
    /// wird, der Code nie.
    ///
    /// Fällt eine Übersetzung aus der Datenbank, verschwindet ihre Zeile mit
    /// ihr, ohne Codeänderung. Kommt eine dazu, für die der Katalog noch nichts
    /// hat, bleibt `translation.copyright` aus der Datenbank stehen — deutsch,
    /// aber vorhanden; eine Rechteangabe darf nie ganz fehlen. Der Unit-Test
    /// `copyrightZeilenSindInAllenSprachenUebersetzt` schlägt dann fehl.
    static func copyright(of translation: Translation) -> String? {
        let key = "copyright.\(translation.code)"
        let localized = String(localized: String.LocalizationValue(key))
        if localized != key, !localized.isEmpty { return localized }
        guard let fallback = translation.copyright, !fallback.isEmpty else { return nil }
        return fallback
    }

    /// Kapitel und Vers ohne Buchname («3,16» / «3:16») — für die runde
    /// Komplikation, in der das Kürzel über den Zahlen steht und der volle Name
    /// nicht hinpasst. Der Trenner ist derselbe wie in `reference`: er gehört
    /// auch hier in den Katalog und darf nicht fest verdrahtet werden.
    ///
    /// `Int64(...)` ist Pflicht: auf der Uhr (arm64_32) ist `Int` 32 Bit breit,
    /// `%lld` liest 64 Bit.
    static func chapterVerse(chapter: Int, verse: Int) -> String {
        String(format: String(localized: "reference.chapterVerse %1$lld %2$lld"),
               Int64(chapter), Int64(verse))
    }

    /// Zahlen der Zählerzeile mit den Trennzeichen der jeweiligen Region:
    /// Schweizer Deutsch 31’103, Englisch 31,103.
    static func groupedNumber(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    /// Stellenangabe ohne Vers («Psalm 23» / "Psalm 23"). Der Katalogschlüssel
    /// verwendet Positionsangaben (%1$@ %2$lld); SwiftUI-Interpolation erzeugt
    /// %@ %lld und fände ihn nicht — darum String(format:).
    ///
    /// `Int64(...)` ist Pflicht, keine Kosmetik: auf der Uhr (arm64_32) ist `Int`
    /// 32 Bit breit, `%lld` liest aber 64 Bit. Ohne die Umwandlung steht auf dem
    /// Gerät «2. Petrus 0» — im Simulator (arm64, 64 Bit) sieht man nichts davon.
    static func chapterReference(book: Book, chapter: Int) -> String {
        String(format: String(localized: "reference.chapter %1$@ %2$lld"),
               name(of: book), Int64(chapter))
    }

    /// Zählerzeile des Zufallsverses («3 / 463»): die wievielte Seite dieses
    /// Durchgangs, und wie viele Verse die Gruppe hat, aus der gezogen wird.
    static func position(_ ordinal: Int, of total: Int) -> String {
        String(format: String(localized: "random.position %1$@ %2$@"),
               groupedNumber(ordinal), groupedNumber(total))
    }

    /// VoiceOver-Fassung der Zählerzeile.
    static func positionAccessibility(_ ordinal: Int, of total: Int) -> String {
        String(format: String(localized: "random.position.a11y %1$@ %2$@"),
               groupedNumber(ordinal), groupedNumber(total))
    }
}
