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
            NavigationStack {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        destination(for: route)
                    }
            }
        }
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
