import SwiftUI
import WatchKit

struct VerseDetailView: View {
    let verseText: String
    let book: BibleDatabase.Book
    let chapter: Int
    let verse: Int
    @StateObject private var database = BibleDatabase()
    @State private var currentVerseText: String
    @State private var currentBook: BibleDatabase.Book
    @State private var currentChapter: Int
    @State private var currentVerse: Int
    
    private var formattedContent: (mainText: String, footnotes: [String]) {
        var mainText = currentVerseText
        var footnotes: [String] = []
        var currentFootnoteIndex = 1
        
        // Extract footnotes with proper brace matching
        while let startRange = mainText.range(of: "\\biblefootnote{") {
            let contentStart = startRange.upperBound
            var braceCount = 1
            var currentIndex = contentStart
            var endIndex: String.Index?
            
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
                let cleanFootnote = processText(footnoteContent)
                footnotes.append(cleanFootnote)
                mainText.replaceSubrange(footnoteRange, with: "¹")
                currentFootnoteIndex += 1
            }
        }
        
        mainText = processText(mainText)
        return (mainText.trimmingCharacters(in: .whitespacesAndNewlines), footnotes)
    }
    
    private func processText(_ text: String) -> String {
        var processedText = text
        
        // Handle quotes first
        processedText = processedText
            .replacingOccurrences(of: "\\flqq{}", with: "\u{201E}")
            .replacingOccurrences(of: "\\frqq{}", with: "\u{201C}")
        
        // Handle textsc command
        while let startRange = processedText.range(of: "\\textsc{") {
            let contentStart = startRange.upperBound
            var braceCount = 1
            var currentIndex = contentStart
            var endIndex: String.Index?
            
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
        
        // Handle textit command (italic)
        while let startRange = processedText.range(of: "\\textit{") {
            let contentStart = startRange.upperBound
            var braceCount = 1
            var currentIndex = contentStart
            var endIndex: String.Index?
            
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
                processedText.replaceSubrange(fullRange, with: "_\(content)_")
            }
        }
        
        // Handle textbf command (bold)
        while let startRange = processedText.range(of: "\\textbf{") {
            let contentStart = startRange.upperBound
            var braceCount = 1
            var currentIndex = contentStart
            var endIndex: String.Index?
            
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
                processedText.replaceSubrange(fullRange, with: "*\(content)*")
            }
        }
        
        return processedText
            .replacingOccurrences(of: "}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    init(verseText: String, book: BibleDatabase.Book, chapter: Int, verse: Int) {
        self.verseText = verseText
        self.book = book
        self.chapter = chapter
        self.verse = verse
        _currentVerseText = State(initialValue: verseText)
        _currentBook = State(initialValue: book)
        _currentChapter = State(initialValue: chapter)
        _currentVerse = State(initialValue: verse)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main verse text with markdown support
                Text(LocalizedStringKey(formattedContent.mainText))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
                
                // Footnotes with markdown support
                if !formattedContent.footnotes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(formattedContent.footnotes.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 4) {
                                Text("\(index + 1)")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .baselineOffset(5)
                                Text(LocalizedStringKey(formattedContent.footnotes[index]))
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
        .navigationTitle("\(currentBook.name) \(currentChapter):\(currentVerse)")
    }
} 