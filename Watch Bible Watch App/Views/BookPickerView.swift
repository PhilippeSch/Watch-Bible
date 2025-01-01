import SwiftUI

struct BookPickerView: View {
    let books: [BibleDatabase.Book]
    @Binding var selectedBook: BibleDatabase.Book?
    let title: String
    
    var body: some View {
        List {
            ForEach(books) { book in
                NavigationLink {
                    ChapterPickerView(book: book)
                } label: {
                    HStack {
                        Text(book.name)
                            .foregroundColor(book.testament.color)
                        Spacer()
                        if book.id == selectedBook?.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
    }
} 