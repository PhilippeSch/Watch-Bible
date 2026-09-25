import Foundation

/// Der Deep Link des Widgets: `watchbible://verse/<buchID>/<kapitel>/<vers>`
/// (docs/Architektur.md, Kap. 8). Das Widget setzt ihn zusammen, die App liest
/// ihn, beide ueber diese Datei, damit das Schema nur einmal geschrieben steht.
///
/// Das Schema ist nicht als URL-Typ registriert und braucht das nicht:
/// `widgetURL` reicht die URL direkt an die eigene App durch.
enum DeepLink {

    static let scheme = "watchbible"
    static let verseHost = "verse"

    /// URL zu einer Stelle, wie das Widget sie per `widgetURL` mitgibt.
    static func url(for ref: VerseReference) -> URL? {
        URL(string: "\(scheme)://\(verseHost)/\(ref.bookID)/\(ref.chapter)/\(ref.verse)")
    }

    /// Die Stelle aus einer URL; `nil` fuer alles, was nicht genau dem Schema
    /// entspricht. Ob das Buch existiert, prueft die App gegen ihre Stammdaten.
    static func verseReference(from url: URL) -> VerseReference? {
        guard url.scheme == scheme, url.host() == verseHost else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        let numbers = components.compactMap(Int.init)
        guard components.count == 3, numbers.count == 3 else { return nil }
        return VerseReference(bookID: numbers[0], chapter: numbers[1], verse: numbers[2])
    }
}
