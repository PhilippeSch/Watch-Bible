import SwiftUI

struct ChapterPickerView: View {
    let book: BibleDatabase.Book
    @StateObject private var database = BibleDatabase.shared
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(1...book.chapters, id: \.self) { chapter in
                    NavigationLink {
                        VersePickerView(
                            book: book,
                            chapter: chapter
                        )
                    } label: {
                        Text("\(chapter)")
                            .frame(minWidth: 44, minHeight: 44)
                            .background(Color.gray.opacity(0.0))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(book.name)
    }
} 