import SwiftUI

struct VersePickerView: View {
    let book: BibleDatabase.Book
    let chapter: Int
    @StateObject private var database = BibleDatabase()
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(1...database.getMaxVerses(book: book.id, chapter: chapter), id: \.self) { verse in
                    NavigationLink {
                        if let verseText = database.getVerse(translation: "slt", book: book.id, chapter: chapter, verse: verse) {
                            VerseDetailView(
                                verseText: verseText,
                                book: book,
                                chapter: chapter,
                                verse: verse
                            )
                        }
                    } label: {
                        Text("\(verse)")
                            .frame(minWidth: 44, minHeight: 44)
                            .background(Color.gray.opacity(0.0))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("\(book.name) \(chapter)")
    }
} 