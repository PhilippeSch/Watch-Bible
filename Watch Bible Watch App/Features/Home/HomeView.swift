import SwiftUI

/// Einstieg (Designspezifikation 4.1): Zufallsvers, Nachschlagen, darunter
/// Einstellungen. Gab es eine zuletzt gelesene Stelle, erscheint sie als
/// «Weiterlesen»-Zeile. Kein Splash, kein Onboarding.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                row("home.random", route: .random)
                row("home.topics", route: .topics)
                row("home.lookup", route: .books)
                continueRow
                row("home.settings", route: .settings, secondary: true)
            }
            .padding(.horizontal, 2)
        }
        .containerBackground(Color.ground, for: .navigation)
    }

    @ViewBuilder
    private var continueRow: some View {
        if let ref = model.settings.lastReference,
           let book = model.book(id: ref.bookID) {
            NavigationLink(value: Route.reader(bookID: ref.bookID,
                                               chapter: ref.chapter,
                                               verse: ref.verse)) {
                HStack {
                    Text("home.continue \(Localization.reference(ref, book: book))")
                        .font(Typo.bookRow)
                        .foregroundStyle(Color.carmine)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: Grid3.cornerRadius)
                        .fill(Color.fieldFill)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ key: LocalizedStringKey, route: Route,
                     secondary: Bool = false) -> some View {
        NavigationLink(value: route) {
            HStack {
                Text(key)
                    .font(Typo.homeRow)
                    .foregroundStyle(secondary ? Color.secondaryInk : Color.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Grid3.cornerRadius)
                    .fill(Color.fieldFill)
            )
        }
        .buttonStyle(.plain)
    }
}
