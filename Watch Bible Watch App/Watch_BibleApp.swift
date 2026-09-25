//
//  Watch_BibleApp.swift
//  Watch Bible Watch App
//
//  Created by Philippe Scheuber on 01.01.2025.
//

import SwiftUI

@main
struct Watch_Bible_Watch_AppApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modifier(ThemeApplier(settings: model.settings))
                .task { await model.start() }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var path = NavigationPath()

    /// Zaehlt die Deep Links; die Leseansicht traegt den Stand als `.id`.
    ///
    /// `show(_:)` setzt den Stapel zurueck und legt die Leseansicht neu auf.
    /// Stand dort schon eine (Weiterlesen, Zufallsvers, ein frueherer Tipp
    /// aufs Widget), bleibt sie an derselben Stelle des Stapels, und SwiftUI
    /// behielte die Ansicht samt ihrem `@State`: der alte Vers bliebe stehen.
    /// Die Route allein taugt nicht als Identitaet, denn Weiterblaettern und
    /// Scrollen aendern sie nicht, und derselbe Link muss am selben Tag
    /// trotzdem frisch oeffnen. Das Weiterblaettern beruehrt den Zaehler
    /// nicht und behaelt seinen Zustand wie bisher.
    @State private var deepLinkGeneration = 0

    /// Stelle eines Deep Links, der ankam, bevor die Datenbank offen war
    /// (Kaltstart). Wird angewendet, sobald der NavigationStack steht.
    @State private var pendingDeepLink: VerseReference?

    var body: some View {
        content
            // Ausserhalb des `switch`: so hat der Link auch waehrend des
            // Ladens einen Empfaenger und laeuft nicht ins Leere.
            .onOpenURL { url in open(url) }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ground.ignoresSafeArea())
        case .failed(let message):
            // Ein fehlendes bible.sqlite ist ein Paketierungsfehler; die App
            // meldet ihn, statt leer dazustehen. Grund und Schriftfarben
            // explizit: diese beiden Zustaende liegen ausserhalb des
            // NavigationStack und bekaemen sonst keinen `containerBackground`.
            VStack(spacing: 6) {
                Text("error.databaseMissing")
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryInk)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ground.ignoresSafeArea())
        case .ready:
            NavigationStack(path: $path) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        destination(for: route)
                    }
            }
            .task {
                // Deep Link vom Kaltstart nachholen, sobald der Stapel steht.
                guard let ref = pendingDeepLink else { return }
                pendingDeepLink = nil
                show(ref)
            }
        }
    }

    /// Deep Link des Widgets (`DeepLink`) oeffnet die Leseansicht auf genau
    /// diesem Vers.
    private func open(_ url: URL) {
        guard let ref = DeepLink.verseReference(from: url) else { return }
        guard case .ready = model.state else {
            // Kaltstart: die Datenbank oeffnet noch, einen Stapel gibt es
            // noch nicht. Merken; `.task` des NavigationStack holt es nach.
            pendingDeepLink = ref
            return
        }
        show(ref)
    }

    private func show(_ ref: VerseReference) {
        guard model.book(id: ref.bookID) != nil else { return }
        path = NavigationPath()
        path.append(Route.reader(bookID: ref.bookID, chapter: ref.chapter, verse: ref.verse))
        deepLinkGeneration += 1
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .random:
            RandomVerseView()
        case .topics:
            TopicListView()
        case .topicVerses(let key):
            // Themen kommen aus der Datenbank; steht der Schluessel nicht mehr
            // darin (andere Datenbank, Thema entfernt), bleibt es beim
            // Zufallsvers ueber alles, statt einen leeren Bildschirm zu zeigen.
            RandomVerseView(topic: model.topic(key: key))
        case .books:
            BookListView()
        case .chapters(let bookID):
            ChapterGridView(bookID: bookID)
        case .verses(let bookID, let chapter):
            VerseGridView(bookID: bookID, chapter: chapter)
        case .reader(let bookID, let chapter, let verse):
            ReaderView(bookID: bookID, chapter: chapter, highlight: verse)
                // Neue Identitaet je Deep Link, siehe `deepLinkGeneration`.
                .id(deepLinkGeneration)
        case .settings:
            SettingsView()
        case .translationPicker:
            TranslationPickerView()
        case .about:
            AboutView()
        }
    }
}
