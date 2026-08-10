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

    var body: some View {
        switch model.state {
        case .loading:
            ProgressView()
        case .failed(let message):
            // Ein fehlendes bible.sqlite ist ein Paketierungsfehler; die App
            // meldet ihn, statt leer dazustehen.
            VStack(spacing: 6) {
                Text("error.databaseMissing")
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        case .ready:
            NavigationStack(path: $path) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        destination(for: route)
                    }
            }
            .onOpenURL { url in open(url) }
        }
    }

    /// Deep Link des Widgets: watchbible://verse/<bookID>/<kapitel>/<vers>
    /// oeffnet die Leseansicht auf genau diesem Vers.
    private func open(_ url: URL) {
        guard url.scheme == "watchbible", url.host() == "verse" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }.compactMap(Int.init)
        guard parts.count == 3, model.book(id: parts[0]) != nil else { return }
        path = NavigationPath()
        path.append(Route.reader(bookID: parts[0], chapter: parts[1], verse: parts[2]))
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .random:
            RandomVerseView()
        case .books:
            BookListView()
        case .chapters(let bookID):
            ChapterGridView(bookID: bookID)
        case .verses(let bookID, let chapter):
            VerseGridView(bookID: bookID, chapter: chapter)
        case .reader(let bookID, let chapter, let verse):
            ReaderView(bookID: bookID, chapter: chapter, highlight: verse)
        case .settings:
            SettingsView()
        case .translationPicker:
            TranslationPickerView()
        case .about:
            AboutView()
        }
    }
}
