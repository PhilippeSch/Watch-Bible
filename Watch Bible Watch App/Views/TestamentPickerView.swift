import SwiftUI

struct TestamentPickerView: View {
    let books: [BibleDatabase.Book]
    @Binding var selectedBook: BibleDatabase.Book?
    
    var body: some View {
        List {
            NavigationLink {
                BookPickerView(
                    books: books.filter { $0.testament == .old },
                    selectedBook: $selectedBook,
                    title: "Altes Testament"
                )
            } label: {
                Text("Altes Testament")
                    .foregroundColor(BibleDatabase.Testament.old.color)
            }
            
            NavigationLink {
                BookPickerView(
                    books: books.filter { $0.testament == .new },
                    selectedBook: $selectedBook,
                    title: "Neues Testament"
                )
            } label: {
                Text("Neues Testament")
                    .foregroundColor(BibleDatabase.Testament.new.color)
            }
        }
        .navigationTitle("Testament")
    }
} 