import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var database = BibleDatabase()
    @State private var selectedTranslation = "slt"
    @State private var selectedBook: BibleDatabase.Book?
    @State private var selectedChapter = 1
    @State private var selectedVerse = 1
    @State private var verseText: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                // Translation Button
                NavigationLink {
                    TranslationPickerView(
                        translations: database.getTranslations(),
                        selectedTranslation: $selectedTranslation
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Übersetzung")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        if let translation = database.getTranslations().first(where: { $0.id == selectedTranslation }) {
                            Text(translation.name)
                        }
                    }
                }
                
                // Book Button
                if let book = selectedBook {
                    NavigationLink {
                        TestamentPickerView(
                            books: database.getBooks(),
                            selectedBook: $selectedBook
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bibel Buch")
                                .font(.footnote)
                                .foregroundColor(.gray)
                            Text(book.name)
                                .foregroundColor(book.testament.color)
                        }
                    }
                    
                    // Chapter and Verse Selection Button
                    NavigationLink {
                        ChapterPickerView(book: book)
                    } label: {
                        Text("Kapitel & Vers auswählen")
                    }
                } else {
                    NavigationLink {
                        TestamentPickerView(
                            books: database.getBooks(),
                            selectedBook: $selectedBook
                        )
                    } label: {
                        Text("Bibel Buch auswählen")
                    }
                }
                
                // Verse Text (only show if verse is selected)
                if !verseText.isEmpty {
                    NavigationLink {
                        VerseDetailView(
                            verseText: verseText,
                            book: selectedBook!,
                            chapter: selectedChapter,
                            verse: selectedVerse
                        )
                    } label: {
                        Text(verseText)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Bibel")
            .navigationBarBackButtonHidden(true)
        }
        .onChange(of: selectedBook) { oldValue, newValue in
            selectedChapter = 1
            selectedVerse = 1
            updateVerse()
        }
        .onChange(of: selectedChapter) { oldValue, newValue in
            selectedVerse = 1
            updateVerse()
        }
        .onChange(of: selectedVerse) { oldValue, newValue in
            updateVerse()
        }
        .onChange(of: selectedTranslation) { oldValue, newValue in
            updateVerse()
        }
    }
    
    private func updateVerse() {
        if let verse = database.getVerse(
            translation: selectedTranslation,
            book: selectedBook?.id ?? 0,
            chapter: selectedChapter,
            verse: selectedVerse
        ) {
            verseText = verse
        }
    }
}

#Preview {
    ContentView()
} 