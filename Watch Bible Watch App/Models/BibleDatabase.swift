import Foundation
import SwiftUI

class BibleDatabase: ObservableObject {
    // MARK: - Data Models
    struct Translation: Identifiable {
        let id: String
        let name: String
    }
    
    enum Testament {
        case old
        case new
        
        var color: Color {
            switch self {
            case .old: return Color(red: 0.7, green: 0.2, blue: 0.2) // Dark red
            case .new: return Color(red: 0.2, green: 0.5, blue: 0.2) // Dark green
            }
        }
    }
    
    struct Book: Identifiable, Equatable {
        let id: Int
        let label: String      // Abbreviation for database
        let name: String       // Friendly name
        let testament: Testament
        let chapters: Int
        
        static func == (lhs: Book, rhs: Book) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    // MARK: - Properties
    @Published private(set) var isDatabaseReady = false
    private var verseCache: [String: [Int: String]] = [:] // [bookChapterKey: [verse: text]]
    private var bibleText: String = ""
    
    // MARK: - Initialization
    init() {
        loadBibleFile()
    }
    
    // MARK: - Private Methods
    private func loadBibleFile() {
        if let path = Bundle.main.path(forResource: "bible", ofType: "db"),
           let data = try? String(contentsOfFile: path, encoding: .utf8) {
            bibleText = data
            isDatabaseReady = true
            print("Bible file loaded successfully")
        } else {
            print("Could not find or load bible.db file")
        }
    }
    
    private func loadVersesForChapter(translation: String, book: String, chapter: Int) {
        let chapterKey = "\(translation)\(book)\(chapter)"
        
        // Skip if already cached
        guard verseCache[chapterKey] == nil else { return }
        
        var verses: [Int: String] = [:]
        
        // Split the file into individual quotepas elements and process only matching verses
        let quoteElements = bibleText.components(separatedBy: "<quotepas>")
        
        for quote in quoteElements {
            if let labelRange = quote.range(of: "<label>"),
               let labelEndRange = quote.range(of: "</label>") {
                let label = String(quote[labelRange.upperBound..<labelEndRange.lowerBound])
                
                // Only process if label matches our chapter
                if label.hasPrefix("\(translation)\(book)\(chapter)v") {
                    if let blockRange = quote.range(of: "<block>"),
                       let blockEndRange = quote.range(of: "</block>"),
                       let verseNumber = Int(label.replacingOccurrences(of: "\(translation)\(book)\(chapter)v", with: "")) {
                        let block = String(quote[blockRange.upperBound..<blockEndRange.lowerBound])
                        verses[verseNumber] = block
                    }
                }
            }
        }
        
        verseCache[chapterKey] = verses
        print("Loaded \(verses.count) verses for \(chapterKey)")
    }
    
    // MARK: - Public Methods
    func getTranslations() -> [Translation] {
        return [
            Translation(id: "slt", name: "Schlachter 2000"),
            Translation(id: "elb", name: "Elberfelder 1905"),
            Translation(id: "dar", name: "Darby Bible"),
            Translation(id: "kjv", name: "King James Bible")
        ]
    }
    
    func getBooks() -> [Book] {
        return [
            // Old Testament (AT)
            Book(id: 1, label: "1Mo", name: "1. Mose", testament: .old, chapters: 50),
            Book(id: 2, label: "2Mo", name: "2. Mose", testament: .old, chapters: 40),
            Book(id: 3, label: "3Mo", name: "3. Mose", testament: .old, chapters: 27),
            Book(id: 4, label: "4Mo", name: "4. Mose", testament: .old, chapters: 36),
            Book(id: 5, label: "5Mo", name: "5. Mose", testament: .old, chapters: 34),
            Book(id: 6, label: "Jos", name: "Josua", testament: .old, chapters: 24),
            Book(id: 7, label: "Ri", name: "Richter", testament: .old, chapters: 21),
            Book(id: 8, label: "Rt", name: "Ruth", testament: .old, chapters: 4),
            Book(id: 9, label: "1Sam", name: "1. Samuel", testament: .old, chapters: 31),
            Book(id: 10, label: "2Sam", name: "2. Samuel", testament: .old, chapters: 24),
            Book(id: 11, label: "1Kon", name: "1. Könige", testament: .old, chapters: 22),
            Book(id: 12, label: "2Kon", name: "2. Könige", testament: .old, chapters: 25),
            Book(id: 13, label: "1Chr", name: "1. Chronik", testament: .old, chapters: 29),
            Book(id: 14, label: "2Chr", name: "2. Chronik", testament: .old, chapters: 36),
            Book(id: 15, label: "Esr", name: "Esra", testament: .old, chapters: 10),
            Book(id: 16, label: "Neh", name: "Nehemia", testament: .old, chapters: 13),
            Book(id: 17, label: "Est", name: "Esther", testament: .old, chapters: 10),
            Book(id: 18, label: "Hi", name: "Hiob", testament: .old, chapters: 42),
            Book(id: 19, label: "Ps", name: "Psalmen", testament: .old, chapters: 150),
            Book(id: 20, label: "Spr", name: "Sprüche", testament: .old, chapters: 31),
            Book(id: 21, label: "Pred", name: "Prediger", testament: .old, chapters: 12),
            Book(id: 22, label: "Hl", name: "Hohelied", testament: .old, chapters: 8),
            Book(id: 23, label: "Jes", name: "Jesaja", testament: .old, chapters: 66),
            Book(id: 24, label: "Jer", name: "Jeremia", testament: .old, chapters: 52),
            Book(id: 25, label: "Kla", name: "Klagelieder", testament: .old, chapters: 5),
            Book(id: 26, label: "Hes", name: "Hesekiel", testament: .old, chapters: 48),
            Book(id: 27, label: "Dan", name: "Daniel", testament: .old, chapters: 12),
            Book(id: 28, label: "Hos", name: "Hosea", testament: .old, chapters: 14),
            Book(id: 29, label: "Joel", name: "Joel", testament: .old, chapters: 3),
            Book(id: 30, label: "Am", name: "Amos", testament: .old, chapters: 9),
            Book(id: 31, label: "Ob", name: "Obadja", testament: .old, chapters: 1),
            Book(id: 32, label: "Jon", name: "Jona", testament: .old, chapters: 4),
            Book(id: 33, label: "Mi", name: "Micha", testament: .old, chapters: 7),
            Book(id: 34, label: "Nah", name: "Nahum", testament: .old, chapters: 3),
            Book(id: 35, label: "Hab", name: "Habakuk", testament: .old, chapters: 3),
            Book(id: 36, label: "Zeph", name: "Zephanja", testament: .old, chapters: 3),
            Book(id: 37, label: "Hag", name: "Haggai", testament: .old, chapters: 2),
            Book(id: 38, label: "Sach", name: "Sacharja", testament: .old, chapters: 14),
            Book(id: 39, label: "Mal", name: "Maleachi", testament: .old, chapters: 4),
            
            // New Testament (NT)
            Book(id: 40, label: "Mt", name: "Matthäus", testament: .new, chapters: 28),
            Book(id: 41, label: "Mk", name: "Markus", testament: .new, chapters: 16),
            Book(id: 42, label: "Lk", name: "Lukas", testament: .new, chapters: 24),
            Book(id: 43, label: "Joh", name: "Johannes", testament: .new, chapters: 21),
            Book(id: 44, label: "Apg", name: "Apostelgeschichte", testament: .new, chapters: 28),
            Book(id: 45, label: "Rom", name: "Römer", testament: .new, chapters: 16),
            Book(id: 46, label: "1Kor", name: "1. Korinther", testament: .new, chapters: 16),
            Book(id: 47, label: "2Kor", name: "2. Korinther", testament: .new, chapters: 13),
            Book(id: 48, label: "Gal", name: "Galater", testament: .new, chapters: 6),
            Book(id: 49, label: "Eph", name: "Epheser", testament: .new, chapters: 6),
            Book(id: 50, label: "Phil", name: "Philipper", testament: .new, chapters: 4),
            Book(id: 51, label: "Kol", name: "Kolosser", testament: .new, chapters: 4),
            Book(id: 52, label: "1Th", name: "1. Thessalonicher", testament: .new, chapters: 5),
            Book(id: 53, label: "2Th", name: "2. Thessalonicher", testament: .new, chapters: 3),
            Book(id: 54, label: "1Tim", name: "1. Timotheus", testament: .new, chapters: 6),
            Book(id: 55, label: "2Tim", name: "2. Timotheus", testament: .new, chapters: 4),
            Book(id: 56, label: "Tit", name: "Titus", testament: .new, chapters: 3),
            Book(id: 57, label: "Phlm", name: "Philemon", testament: .new, chapters: 1),
            Book(id: 58, label: "Hebr", name: "Hebräer", testament: .new, chapters: 13),
            Book(id: 59, label: "Jak", name: "Jakobus", testament: .new, chapters: 5),
            Book(id: 60, label: "1Pt", name: "1. Petrus", testament: .new, chapters: 5),
            Book(id: 61, label: "2Pt", name: "2. Petrus", testament: .new, chapters: 3),
            Book(id: 62, label: "1Joh", name: "1. Johannes", testament: .new, chapters: 5),
            Book(id: 63, label: "2Joh", name: "2. Johannes", testament: .new, chapters: 1),
            Book(id: 64, label: "3Joh", name: "3. Johannes", testament: .new, chapters: 1),
            Book(id: 65, label: "Jud", name: "Judas", testament: .new, chapters: 1),
            Book(id: 66, label: "Offb", name: "Offenbarung", testament: .new, chapters: 22)
        ]
    }
    
    func getVerse(translation: String, book: Int, chapter: Int, verse: Int) -> String? {
        guard isDatabaseReady,
              let bookLabel = getBooks().first(where: { $0.id == book })?.label else {
            return nil
        }
        
        let chapterKey = "\(translation)\(bookLabel)\(chapter)"
        
        // Load verses for this chapter if not cached
        if verseCache[chapterKey] == nil {
            loadVersesForChapter(translation: translation, book: bookLabel, chapter: chapter)
        }
        
        return verseCache[chapterKey]?[verse]
    }
    
    func getMaxVerses(book: Int, chapter: Int) -> Int {
        guard isDatabaseReady,
              let bookLabel = getBooks().first(where: { $0.id == book })?.label else {
            return 0
        }
        
        let chapterKey = "slt\(bookLabel)\(chapter)"
        
        // Load verses if not cached
        if verseCache[chapterKey] == nil {
            loadVersesForChapter(translation: "slt", book: bookLabel, chapter: chapter)
        }
        
        return verseCache[chapterKey]?.count ?? 0
    }
} 
