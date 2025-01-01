import SwiftUI

struct ContentView: View {
    @State private var selectedTranslation = "SCH2000"
    @State private var selectedBook = 1
    @State private var selectedChapter = 1
    @State private var selectedVerse = 1
    
    private let database = BibleDatabase()
    @State private var verseText: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Translation Picker
                NavigationLink(destination: TranslationPicker(selection: $selectedTranslation)) {
                    Text("Translation: \(selectedTranslation)")
                        .frame(minWidth: 44, minHeight: 44) // Following Apple's touch target guidelines
                }
                
                // Book Picker
                Picker("Book", selection: $selectedBook) {
                    ForEach(1...66, id: \.self) { book in
                        Text("Book \(book)")
                    }
                }
                .frame(height: 44)
                
                // Chapter Picker
                Picker("Chapter", selection: $selectedChapter) {
                    ForEach(1...50, id: \.self) { chapter in
                        Text("\(chapter)")
                    }
                }
                .frame(height: 44)
                
                // Verse Picker
                Picker("Verse", selection: $selectedVerse) {
                    ForEach(1...database.getMaxVerses(book: selectedBook, chapter: selectedChapter), id: \.self) { verse in
                        Text("\(verse)")
                    }
                }
                .frame(height: 44)
                
                // Verse Text
                Text(verseText)
                    .font(.system(size: 16)) // Following Apple's text size guidelines
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .onChange(of: selectedTranslation) { _ in updateVerse() }
            .onChange(of: selectedBook) { _ in updateVerse() }
            .onChange(of: selectedChapter) { _ in updateVerse() }
            .onChange(of: selectedVerse) { _ in updateVerse() }
        }
    }
    
    private func updateVerse() {
        if let verse = database.getVerse(
            translation: selectedTranslation,
            book: selectedBook,
            chapter: selectedChapter,
            verse: selectedVerse
        ) {
            verseText = verse
        }
    }
} 