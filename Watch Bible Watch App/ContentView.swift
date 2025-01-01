//
//  ContentView.swift
//  Watch Bible Watch App
//
//  Created by Philippe Scheuber on 01.01.2025.
//

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
                        ChapterPickerView(
                            book: book
                        )
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
        .onChange(of: selectedBook) { _, _ in
            selectedChapter = 1
            selectedVerse = 1
            updateVerse()
        }
        .onChange(of: selectedChapter) { _, _ in
            selectedVerse = 1
            updateVerse()
        }
        .onChange(of: selectedVerse) { _, _ in
            updateVerse()
        }
        .onChange(of: selectedTranslation) { _, _ in
            updateVerse()
        }
    }
    
    private func updateVerse() {
        if let book = selectedBook,
           let verse = database.getVerse(
            translation: selectedTranslation,
            book: book.id,
            chapter: selectedChapter,
            verse: selectedVerse
           ) {
            verseText = verse
        } else {
            verseText = ""
        }
    }
}

struct ChapterPickerView: View {
    let book: BibleDatabase.Book
    @StateObject private var database = BibleDatabase()
    
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

struct VerseDetailView: View {
    let verseText: String
    let book: BibleDatabase.Book
    let chapter: Int
    let verse: Int
    
    // Parse verse text and footnotes
    private var formattedContent: (mainText: String, footnotes: [String]) {
        var mainText = verseText
        var footnotes: [String] = []
        var currentFootnoteIndex = 1
        
        // Extract footnotes with proper brace matching
        while let startRange = mainText.range(of: "\\biblefootnote{") {
            let contentStart = startRange.upperBound
            var braceCount = 1
            var currentIndex = contentStart
            var endIndex: String.Index?
            
            // Find matching closing brace
            while currentIndex < mainText.endIndex {
                let char = mainText[currentIndex]
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        endIndex = currentIndex
                        break
                    }
                }
                currentIndex = mainText.index(after: currentIndex)
            }
            
            if let endIndex = endIndex {
                let footnoteRange = startRange.lowerBound..<mainText.index(after: endIndex)
                let footnoteContent = String(mainText[contentStart..<endIndex])
                
                // Process the footnote text
                let cleanFootnote = processText(footnoteContent)
                footnotes.append(cleanFootnote)
                
                // Replace footnote with superscript number
                mainText.replaceSubrange(footnoteRange, with: "¹")
                currentFootnoteIndex += 1
            }
        }
        
        // Format main text
        mainText = processText(mainText)
        
        return (mainText.trimmingCharacters(in: .whitespacesAndNewlines), footnotes)
    }
    
    // Update helper function for text processing
    private func processText(_ text: String) -> String {
        var processedText = text
        
        // Handle quotes first
        processedText = processedText
            .replacingOccurrences(of: "\\flqq{}", with: "\u{201E}")
            .replacingOccurrences(of: "\\frqq{}", with: "\u{201C}")
        
        // Simply remove textsc command and keep normal text
        while let startRange = processedText.range(of: "\\textsc{") {
            let contentStart = startRange.upperBound
            var braceCount = 1
            var currentIndex = contentStart
            var endIndex: String.Index?
            
            // Find matching closing brace
            while currentIndex < processedText.endIndex {
                let char = processedText[currentIndex]
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        endIndex = currentIndex
                        break
                    }
                }
                currentIndex = processedText.index(after: currentIndex)
            }
            
            if let endIndex = endIndex {
                let fullRange = startRange.lowerBound..<processedText.index(after: endIndex)
                let content = String(processedText[contentStart..<endIndex])
                processedText.replaceSubrange(fullRange, with: content)
            }
        }
        
        // Clean up any remaining braces
        return processedText.replacingOccurrences(of: "}", with: "")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main verse text
                Text(formattedContent.mainText)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
                
                // Footnotes
                if !formattedContent.footnotes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(formattedContent.footnotes.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 4) {
                                Text("\(index + 1)")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .baselineOffset(5) // Make number slightly superscript
                                Text(formattedContent.footnotes[index])
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
        .navigationTitle("\(book.name) \(chapter):\(verse)")
    }
}

// MARK: - Supporting Views
struct TranslationPickerView: View {
    let translations: [BibleDatabase.Translation]
    @Binding var selectedTranslation: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List(translations) { translation in
            Button {
                selectedTranslation = translation.id
                dismiss()
            } label: {
                HStack {
                    Text(translation.name)
                    Spacer()
                    if translation.id == selectedTranslation {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
        .navigationTitle("Übersetzung")
    }
}

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

#Preview {
    ContentView()
}
