import SwiftUI
import WatchKit

struct VerseDetailView: View {
    let book: BibleDatabase.Book
    let chapter: Int
    let verse: Int
    @StateObject private var database = BibleDatabase.shared
    @State private var formattedVerse: BibleDatabase.FormattedVerse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else if isLoading {
                ProgressView()
            } else if let content = formattedVerse {
                ScrollView {
                    VStack(spacing: 16) {
                        Text(LocalizedStringKey(content.mainText))
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 8)
                        
                        if !content.footnotes.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(content.footnotes.indices, id: \.self) { index in
                                    HStack(alignment: .top, spacing: 4) {
                                        Text("\(index + 1)")
                                            .font(.footnote)
                                            .foregroundColor(.gray)
                                            .baselineOffset(5)
                                        Text(LocalizedStringKey(content.footnotes[index]))
                                            .font(.footnote)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            } else {
                Text("Verse not found")
                    .foregroundColor(.red)
            }
        }
        .task {
            isLoading = true
            formattedVerse = database.getFormattedVerse(translation: "slt", book: book.id, chapter: chapter, verse: verse)
            isLoading = false
        }
        .navigationTitle("\(book.name) \(chapter):\(verse)")
    }
} 