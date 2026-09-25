import Foundation

/// Der Deep Link des Widgets:
/// `watchbible://verse/<buchID>/<kapitel>/<vers>?translation=<code>`
/// (docs/Architektur.md, Kap. 8). Das Widget setzt ihn zusammen, die App liest
/// ihn, beide ueber diese Datei, damit das Schema nur einmal geschrieben steht.
///
/// Die Uebersetzung steht mit drin, weil Widget und App nicht dieselbe zeigen
/// muessen: das Widget nimmt die Vorgabe der Systemsprache (kein App Group,
/// Kap. 1), die App die gewaehlte. Dieselbe Stelle kann dort ein anderer Text
/// sein (Kap. 5), und die Leseansicht macht das ueber `resolve` sichtbar.
///
/// Das Schema ist nicht als URL-Typ registriert und braucht das nicht:
/// `widgetURL` reicht die URL direkt an die eigene App durch.
struct DeepLink: Hashable, Sendable {

    static let scheme = "watchbible"
    static let verseHost = "verse"
    static let translationItem = "translation"

    let reference: VerseReference
    /// Code der Uebersetzung, in der das Widget den Vers gezeigt hat. `nil`
    /// bei einem Link ohne Angabe; die App oeffnet die Stelle dann ohne
    /// Abgleich in der aktiven.
    let translationCode: String?

    init(reference: VerseReference, translationCode: String?) {
        self.reference = reference
        self.translationCode = translationCode
    }

    /// Liest eine URL; `nil` fuer alles, was nicht genau dem Schema
    /// entspricht. Ob das Buch existiert, prueft die App gegen ihre Stammdaten.
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == Self.scheme, components.host == Self.verseHost
        else { return nil }
        let parts = components.path.split(separator: "/").map { String($0) }
        let numbers = parts.compactMap { Int($0) }
        guard parts.count == 3, numbers.count == 3 else { return nil }
        reference = VerseReference(bookID: numbers[0], chapter: numbers[1], verse: numbers[2])
        translationCode = components.queryItems?
            .first { $0.name == Self.translationItem }?.value
    }

    /// Die URL, wie das Widget sie per `widgetURL` mitgibt.
    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.verseHost
        components.path = "/\(reference.bookID)/\(reference.chapter)/\(reference.verse)"
        if let translationCode {
            components.queryItems = [URLQueryItem(name: Self.translationItem,
                                                  value: translationCode)]
        }
        return components.url
    }
}
