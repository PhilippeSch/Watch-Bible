import Foundation
import SwiftUI

class BibleDatabase: ObservableObject {
    static let shared = BibleDatabase() // Singleton instance
    
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
    
    struct FormattedVerse {
        let mainText: String
        let footnotes: [String]
    }
    
    // MARK: - Properties
    @Published private(set) var isDatabaseReady = false
    private var verseCache: [String: [Int: String]] = [:] // [bookChapterKey: [verse: text]]
    private var bibleText: String = ""
    private var versesPerChapter: [String: Int] = [:]
    private var parsedVerses: [(book: String, chapter: Int, verse: Int)] = []
    private var recentVerseCache = NSCache<NSString, NSString>()
    private var verseLocations: [String: (start: String.Index, end: String.Index)] = [:]
    
    // Static mapping of verse counts: [bookId: [chapter: verseCount]]
    private static let verseCountMap: [Int: [Int: Int]] = [
        // Old Testament
        // 1. Genesis (1. Mose)
        1: [1: 31, 2: 25, 3: 24, 4: 26, 5: 32, 6: 22, 7: 24, 8: 22, 9: 29, 10: 32,
            11: 32, 12: 20, 13: 18, 14: 24, 15: 21, 16: 16, 17: 27, 18: 33, 19: 38, 20: 18,
            21: 34, 22: 24, 23: 20, 24: 67, 25: 34, 26: 35, 27: 46, 28: 22, 29: 35, 30: 43,
            31: 55, 32: 32, 33: 20, 34: 31, 35: 29, 36: 43, 37: 36, 38: 30, 39: 23, 40: 23,
            41: 57, 42: 38, 43: 34, 44: 34, 45: 28, 46: 34, 47: 31, 48: 22, 49: 33, 50: 26],
        
        // 2. Exodus (2. Mose)
        2: [1: 22, 2: 25, 3: 22, 4: 31, 5: 23, 6: 30, 7: 25, 8: 32, 9: 35, 10: 29,
            11: 10, 12: 51, 13: 22, 14: 31, 15: 27, 16: 36, 17: 16, 18: 27, 19: 25, 20: 26,
            21: 36, 22: 31, 23: 33, 24: 18, 25: 40, 26: 37, 27: 21, 28: 43, 29: 46, 30: 38,
            31: 18, 32: 35, 33: 23, 34: 35, 35: 35, 36: 38, 37: 29, 38: 31, 39: 43, 40: 38],
        
        // 3. Leviticus (3. Mose)
        3: [1: 17, 2: 16, 3: 17, 4: 35, 5: 19, 6: 30, 7: 38, 8: 36, 9: 24, 10: 20,
            11: 47, 12: 8, 13: 59, 14: 57, 15: 33, 16: 34, 17: 16, 18: 30, 19: 37, 20: 27,
            21: 24, 22: 33, 23: 44, 24: 23, 25: 55, 26: 46, 27: 34],
        
        // 4. Numbers (4. Mose)
        4: [1: 54, 2: 34, 3: 51, 4: 49, 5: 31, 6: 27, 7: 89, 8: 26, 9: 23, 10: 36,
            11: 35, 12: 16, 13: 33, 14: 45, 15: 41, 16: 50, 17: 13, 18: 32, 19: 22, 20: 29,
            21: 35, 22: 41, 23: 30, 24: 25, 25: 18, 26: 65, 27: 23, 28: 31, 29: 40, 30: 16,
            31: 54, 32: 42, 33: 56, 34: 29, 35: 34, 36: 13],
        
        // 5. Deuteronomy (5. Mose)
        5: [1: 46, 2: 37, 3: 29, 4: 49, 5: 33, 6: 25, 7: 26, 8: 20, 9: 29, 10: 22,
            11: 32, 12: 32, 13: 18, 14: 29, 15: 23, 16: 22, 17: 20, 18: 22, 19: 21, 20: 20,
            21: 23, 22: 30, 23: 25, 24: 22, 25: 19, 26: 19, 27: 26, 28: 68, 29: 29, 30: 20,
            31: 30, 32: 52, 33: 29, 34: 12],
        
        // 6. Joshua
        6: [1: 18, 2: 24, 3: 17, 4: 24, 5: 15, 6: 27, 7: 26, 8: 35, 9: 27, 10: 43,
            11: 23, 12: 24, 13: 33, 14: 15, 15: 63, 16: 10, 17: 18, 18: 28, 19: 51, 20: 9,
            21: 45, 22: 34, 23: 16, 24: 33],
        
        // 7. Judges (Richter)
        7: [1: 36, 2: 23, 3: 31, 4: 24, 5: 31, 6: 40, 7: 25, 8: 35, 9: 57, 10: 18,
            11: 40, 12: 15, 13: 25, 14: 20, 15: 20, 16: 31, 17: 13, 18: 31, 19: 30, 20: 48,
            21: 25],
        
        // 8. Ruth
        8: [1: 22, 2: 23, 3: 18, 4: 22],
        
        // 9. 1 Samuel
        9: [1: 28, 2: 36, 3: 21, 4: 22, 5: 12, 6: 21, 7: 17, 8: 22, 9: 27, 10: 27,
            11: 15, 12: 25, 13: 23, 14: 52, 15: 35, 16: 23, 17: 58, 18: 30, 19: 24, 20: 42,
            21: 15, 22: 23, 23: 29, 24: 22, 25: 44, 26: 25, 27: 12, 28: 25, 29: 11, 30: 31,
            31: 13],
        
        // 10. 2 Samuel
        10: [1: 27, 2: 32, 3: 39, 4: 12, 5: 25, 6: 23, 7: 29, 8: 18, 9: 13, 10: 19,
             11: 27, 12: 31, 13: 39, 14: 33, 15: 37, 16: 23, 17: 29, 18: 33, 19: 43, 20: 26,
             21: 22, 22: 51, 23: 39, 24: 25],
        
        // 11. 1 Kings (1. Könige)
        11: [1: 53, 2: 46, 3: 28, 4: 34, 5: 18, 6: 38, 7: 51, 8: 66, 9: 28, 10: 29,
             11: 43, 12: 33, 13: 34, 14: 31, 15: 34, 16: 34, 17: 24, 18: 46, 19: 21, 20: 43,
             21: 29, 22: 53],
        
        // 12. 2 Kings (2. Könige)
        12: [1: 18, 2: 25, 3: 27, 4: 44, 5: 27, 6: 33, 7: 20, 8: 29, 9: 37, 10: 36,
             11: 21, 12: 21, 13: 25, 14: 29, 15: 38, 16: 20, 17: 41, 18: 37, 19: 37, 20: 21,
             21: 26, 22: 20, 23: 37, 24: 20, 25: 30],
        
        // 13. 1 Chronicles (1. Chronik)
        13: [1: 54, 2: 55, 3: 24, 4: 43, 5: 26, 6: 81, 7: 40, 8: 40, 9: 44, 10: 14,
             11: 47, 12: 40, 13: 14, 14: 17, 15: 29, 16: 43, 17: 27, 18: 17, 19: 19, 20: 8,
             21: 30, 22: 19, 23: 32, 24: 31, 25: 31, 26: 32, 27: 34, 28: 21, 29: 30],
        
        // 14. 2 Chronicles (2. Chronik)
        14: [1: 17, 2: 18, 3: 17, 4: 22, 5: 14, 6: 42, 7: 22, 8: 18, 9: 31, 10: 19,
             11: 23, 12: 16, 13: 22, 14: 15, 15: 19, 16: 14, 17: 19, 18: 34, 19: 11, 20: 37,
             21: 20, 22: 12, 23: 21, 24: 27, 25: 28, 26: 23, 27: 9, 28: 27, 29: 36, 30: 27,
             31: 21, 32: 33, 33: 25, 34: 33, 35: 27, 36: 23],
        
        // 15. Ezra (Esra)
        15: [1: 11, 2: 70, 3: 13, 4: 24, 5: 17, 6: 22, 7: 28, 8: 36, 9: 15, 10: 44],
        
        // 16. Nehemiah (Nehemia)
        16: [1: 11, 2: 20, 3: 32, 4: 23, 5: 19, 6: 19, 7: 73, 8: 18, 9: 38, 10: 39,
             11: 36, 12: 47, 13: 31],
        
        // 17. Esther
        17: [1: 22, 2: 23, 3: 15, 4: 17, 5: 14, 6: 14, 7: 10, 8: 17, 9: 32, 10: 3],
        
        // 18. Job (Hiob)
        18: [1: 22, 2: 13, 3: 26, 4: 21, 5: 27, 6: 30, 7: 21, 8: 22, 9: 35, 10: 22,
             11: 20, 12: 25, 13: 28, 14: 22, 15: 35, 16: 22, 17: 16, 18: 21, 19: 29, 20: 29,
             21: 34, 22: 30, 23: 17, 24: 25, 25: 6, 26: 14, 27: 23, 28: 28, 29: 25, 30: 31,
             31: 40, 32: 22, 33: 33, 34: 37, 35: 16, 36: 33, 37: 24, 38: 41, 39: 30, 40: 24,
             41: 34, 42: 17],
        
        // 19. Psalms (Psalmen)
        19: [1: 6, 2: 12, 3: 8, 4: 8, 5: 12, 6: 10, 7: 17, 8: 9, 9: 20, 10: 18,
             11: 7, 12: 8, 13: 6, 14: 7, 15: 5, 16: 11, 17: 15, 18: 50, 19: 14, 20: 9,
             21: 13, 22: 31, 23: 6, 24: 10, 25: 22, 26: 12, 27: 14, 28: 9, 29: 11, 30: 12,
             31: 24, 32: 11, 33: 22, 34: 22, 35: 28, 36: 12, 37: 40, 38: 22, 39: 13, 40: 17,
             41: 13, 42: 11, 43: 5, 44: 26, 45: 17, 46: 11, 47: 9, 48: 14, 49: 20, 50: 23,
             51: 19, 52: 9, 53: 6, 54: 7, 55: 23, 56: 13, 57: 11, 58: 11, 59: 17, 60: 12,
             61: 8, 62: 12, 63: 11, 64: 10, 65: 13, 66: 20, 67: 7, 68: 35, 69: 36, 70: 5,
             71: 24, 72: 20, 73: 28, 74: 23, 75: 10, 76: 12, 77: 20, 78: 72, 79: 13, 80: 19,
             81: 16, 82: 8, 83: 18, 84: 12, 85: 13, 86: 17, 87: 7, 88: 18, 89: 52, 90: 17,
             91: 16, 92: 15, 93: 5, 94: 23, 95: 11, 96: 13, 97: 12, 98: 9, 99: 9, 100: 5,
             101: 8, 102: 28, 103: 22, 104: 35, 105: 45, 106: 48, 107: 43, 108: 13, 109: 31, 110: 7,
             111: 10, 112: 10, 113: 9, 114: 8, 115: 18, 116: 19, 117: 2, 118: 29, 119: 176, 120: 7,
             121: 8, 122: 9, 123: 4, 124: 8, 125: 5, 126: 6, 127: 5, 128: 6, 129: 8, 130: 8,
             131: 3, 132: 18, 133: 3, 134: 3, 135: 21, 136: 26, 137: 9, 138: 8, 139: 24, 140: 13,
             141: 10, 142: 7, 143: 12, 144: 15, 145: 21, 146: 10, 147: 20, 148: 14, 149: 9, 150: 6],
        
        // 20. Proverbs (Sprüche)
        20: [1: 33, 2: 22, 3: 35, 4: 27, 5: 23, 6: 35, 7: 27, 8: 36, 9: 18, 10: 32,
             11: 31, 12: 28, 13: 25, 14: 35, 15: 33, 16: 33, 17: 28, 18: 24, 19: 29, 20: 30,
             21: 31, 22: 29, 23: 35, 24: 34, 25: 28, 26: 28, 27: 27, 28: 28, 29: 27, 30: 33,
             31: 31],
        
        // 21. Ecclesiastes (Prediger)
        21: [1: 18, 2: 26, 3: 22, 4: 16, 5: 20, 6: 12, 7: 29, 8: 17, 9: 18, 10: 20,
             11: 10, 12: 14],
        
        // 22. Song of Solomon (Hohelied)
        22: [1: 17, 2: 17, 3: 11, 4: 16, 5: 16, 6: 13, 7: 13, 8: 14],
        
        // 23. Isaiah (Jesaja)
        23: [1: 31, 2: 22, 3: 26, 4: 6, 5: 30, 6: 13, 7: 25, 8: 22, 9: 21, 10: 34,
             11: 16, 12: 6, 13: 22, 14: 32, 15: 9, 16: 14, 17: 14, 18: 7, 19: 25, 20: 6,
             21: 17, 22: 25, 23: 18, 24: 23, 25: 12, 26: 21, 27: 13, 28: 29, 29: 24, 30: 33,
             31: 9, 32: 20, 33: 24, 34: 17, 35: 10, 36: 22, 37: 38, 38: 22, 39: 8, 40: 31,
             41: 29, 42: 25, 43: 28, 44: 28, 45: 25, 46: 13, 47: 15, 48: 22, 49: 26, 50: 11,
             51: 23, 52: 15, 53: 12, 54: 17, 55: 13, 56: 12, 57: 21, 58: 14, 59: 21, 60: 22,
             61: 11, 62: 12, 63: 19, 64: 12, 65: 25, 66: 24],
        
        // 24. Jeremiah (Jeremia)
        24: [1: 19, 2: 37, 3: 25, 4: 31, 5: 31, 6: 30, 7: 34, 8: 22, 9: 26, 10: 25,
             11: 23, 12: 17, 13: 27, 14: 22, 15: 21, 16: 21, 17: 27, 18: 23, 19: 15, 20: 18,
             21: 14, 22: 30, 23: 40, 24: 10, 25: 38, 26: 24, 27: 22, 28: 17, 29: 32, 30: 24,
             31: 40, 32: 44, 33: 26, 34: 22, 35: 19, 36: 32, 37: 21, 38: 28, 39: 18, 40: 16,
             41: 18, 42: 22, 43: 13, 44: 30, 45: 5, 46: 28, 47: 7, 48: 47, 49: 39, 50: 46,
             51: 64, 52: 34],
        
        // 25. Lamentations (Klagelieder)
        25: [1: 22, 2: 22, 3: 66, 4: 22, 5: 22],
        
        // 26. Ezekiel (Hesekiel)
        26: [1: 28, 2: 10, 3: 27, 4: 17, 5: 17, 6: 14, 7: 27, 8: 18, 9: 11, 10: 22,
             11: 25, 12: 28, 13: 23, 14: 23, 15: 8, 16: 63, 17: 24, 18: 32, 19: 14, 20: 49,
             21: 32, 22: 31, 23: 49, 24: 27, 25: 17, 26: 21, 27: 36, 28: 26, 29: 21, 30: 26,
             31: 18, 32: 32, 33: 33, 34: 31, 35: 15, 36: 38, 37: 28, 38: 23, 39: 29, 40: 49,
             41: 26, 42: 20, 43: 27, 44: 31, 45: 25, 46: 24, 47: 23, 48: 35],
        
        // 27. Daniel
        27: [1: 21, 2: 49, 3: 30, 4: 37, 5: 31, 6: 28, 7: 28, 8: 27, 9: 27, 10: 21,
             11: 45, 12: 13],
        
        // 28. Hosea
        28: [1: 11, 2: 23, 3: 5, 4: 19, 5: 15, 6: 11, 7: 16, 8: 14, 9: 17, 10: 15,
             11: 12, 12: 14, 13: 16, 14: 9],
        
        // 29. Joel
        29: [1: 20, 2: 32, 3: 21],
        
        // 30. Amos
        30: [1: 15, 2: 16, 3: 15, 4: 13, 5: 27, 6: 14, 7: 17, 8: 14, 9: 15],
        
        // 31. Obadiah (Obadja)
        31: [1: 21],
        
        // 32. Jonah (Jona)
        32: [1: 17, 2: 10, 3: 10, 4: 11],
        
        // 33. Micah (Micha)
        33: [1: 16, 2: 13, 3: 12, 4: 13, 5: 15, 6: 16, 7: 20],
        
        // 34. Nahum
        34: [1: 15, 2: 13, 3: 19],
        
        // 35. Habakkuk (Habakuk)
        35: [1: 17, 2: 20, 3: 19],
        
        // 36. Zephaniah (Zephanja)
        36: [1: 18, 2: 15, 3: 20],
        
        // 37. Haggai
        37: [1: 15, 2: 23],
        
        // 38. Zechariah (Sacharja)
        38: [1: 21, 2: 13, 3: 10, 4: 14, 5: 11, 6: 15, 7: 14, 8: 23, 9: 17, 10: 12,
             11: 17, 12: 14, 13: 9, 14: 21],
        
        // 39. Malachi (Maleachi)
        39: [1: 14, 2: 17, 3: 18, 4: 6],
        
        // New Testament
        // 40. Matthew (Matthäus)
        40: [1: 25, 2: 23, 3: 17, 4: 25, 5: 48, 6: 34, 7: 29, 8: 34, 9: 38, 10: 42,
             11: 30, 12: 50, 13: 58, 14: 36, 15: 39, 16: 28, 17: 27, 18: 35, 19: 30, 20: 34,
             21: 46, 22: 46, 23: 39, 24: 51, 25: 46, 26: 75, 27: 66, 28: 20],
        
        // 41. Mark (Markus)
        41: [1: 45, 2: 28, 3: 35, 4: 41, 5: 43, 6: 56, 7: 37, 8: 38, 9: 50, 10: 52,
             11: 33, 12: 44, 13: 37, 14: 72, 15: 47, 16: 20],
        
        // 42. Luke (Lukas)
        42: [1: 80, 2: 52, 3: 38, 4: 44, 5: 39, 6: 49, 7: 50, 8: 56, 9: 62, 10: 42,
             11: 54, 12: 59, 13: 35, 14: 35, 15: 32, 16: 31, 17: 37, 18: 43, 19: 48, 20: 47,
             21: 38, 22: 71, 23: 56, 24: 53],
        
        // 43. John (Johannes)
        43: [1: 51, 2: 25, 3: 36, 4: 54, 5: 47, 6: 71, 7: 53, 8: 59, 9: 41, 10: 42,
             11: 57, 12: 50, 13: 38, 14: 31, 15: 27, 16: 33, 17: 26, 18: 40, 19: 42, 20: 31,
             21: 25],
        
        // 44. Acts (Apostelgeschichte)
        44: [1: 26, 2: 47, 3: 26, 4: 37, 5: 42, 6: 15, 7: 60, 8: 40, 9: 43, 10: 48,
             11: 30, 12: 25, 13: 52, 14: 28, 15: 41, 16: 40, 17: 34, 18: 28, 19: 41, 20: 38,
             21: 40, 22: 30, 23: 35, 24: 27, 25: 27, 26: 32, 27: 44, 28: 31],
        
        // 45. Romans (Römer)
        45: [1: 32, 2: 29, 3: 31, 4: 25, 5: 21, 6: 23, 7: 25, 8: 39, 9: 33, 10: 21,
             11: 36, 12: 21, 13: 14, 14: 23, 15: 33, 16: 27],
        
        // 46. 1 Corinthians (1. Korinther)
        46: [1: 31, 2: 16, 3: 23, 4: 21, 5: 13, 6: 20, 7: 40, 8: 13, 9: 27, 10: 33,
             11: 34, 12: 31, 13: 13, 14: 40, 15: 58, 16: 24],
        
        // 47. 2 Corinthians (2. Korinther)
        47: [1: 24, 2: 17, 3: 18, 4: 18, 5: 21, 6: 18, 7: 16, 8: 24, 9: 15, 10: 18,
             11: 33, 12: 21, 13: 14],
        
        // 48. Galatians (Galater)
        48: [1: 24, 2: 21, 3: 29, 4: 31, 5: 26, 6: 18],
        
        // 49. Ephesians (Epheser)
        49: [1: 23, 2: 22, 3: 21, 4: 32, 5: 33, 6: 24],
        
        // 50. Philippians (Philipper)
        50: [1: 30, 2: 30, 3: 21, 4: 23],
        
        // 51. Colossians (Kolosser)
        51: [1: 29, 2: 23, 3: 25, 4: 18],
        
        // 52. 1 Thessalonians (1. Thessalonicher)
        52: [1: 10, 2: 20, 3: 13, 4: 18, 5: 28],
        
        // 53. 2 Thessalonians (2. Thessalonicher)
        53: [1: 12, 2: 17, 3: 18],
        
        // 54. 1 Timothy (1. Timotheus)
        54: [1: 20, 2: 15, 3: 16, 4: 16, 5: 25, 6: 21],
        
        // 55. 2 Timothy (2. Timotheus)
        55: [1: 18, 2: 26, 3: 17, 4: 22],
        
        // 56. Titus
        56: [1: 16, 2: 15, 3: 15],
        
        // 57. Philemon
        57: [1: 25],
        
        // 58. Hebrews (Hebräer)
        58: [1: 14, 2: 18, 3: 19, 4: 16, 5: 14, 6: 20, 7: 28, 8: 13, 9: 28, 10: 39,
             11: 40, 12: 29, 13: 25],
        
        // 59. James (Jakobus)
        59: [1: 27, 2: 26, 3: 18, 4: 17, 5: 20],
        
        // 60. 1 Peter (1. Petrus)
        60: [1: 25, 2: 25, 3: 22, 4: 19, 5: 14],
        
        // 61. 2 Peter (2. Petrus)
        61: [1: 21, 2: 22, 3: 18],
        
        // 62. 1 John (1. Johannes)
        62: [1: 10, 2: 29, 3: 24, 4: 21, 5: 21],
        
        // 63. 2 John (2. Johannes)
        63: [1: 13],
        
        // 64. 3 John (3. Johannes)
        64: [1: 14],
        
        // 65. Jude (Judas)
        65: [1: 25],
        
        // 66. Revelation (Offenbarung)
        66: [1: 20, 2: 29, 3: 22, 4: 11, 5: 14, 6: 17, 7: 17, 8: 13, 9: 21, 10: 11,
             11: 19, 12: 17, 13: 18, 14: 20, 15: 8, 16: 21, 17: 18, 18: 24, 19: 21, 20: 15,
             21: 27, 22: 21]
    ]
    
    // MARK: - Initialization
    private init() { // Make initializer private
        loadBibleFile()
        parseVerseStructure()
        indexVerseLocations()
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
    
    private func parseVerseStructure() {
        // Split only once and store the structure
        let quoteElements = bibleText.components(separatedBy: "<quotepas>")
        
        for quote in quoteElements {
            if let labelRange = quote.range(of: "<label>"),
               let labelEndRange = quote.range(of: "</label>") {
                let label = String(quote[labelRange.upperBound..<labelEndRange.lowerBound])
                
                if label.hasPrefix("slt") {
                    let bookChapterVerse = label.replacingOccurrences(of: "slt", with: "")
                    if let bookEndIndex = bookChapterVerse.firstIndex(where: { $0.isNumber }) {
                        let book = String(bookChapterVerse[..<bookEndIndex])
                        let remaining = String(bookChapterVerse[bookEndIndex...])
                        let parts = remaining.split(separator: "v")
                        if parts.count == 2,
                           let chapter = Int(parts[0]),
                           let verse = Int(parts[1]) {
                            // Store the structure
                            parsedVerses.append((book: book, chapter: chapter, verse: verse))
                            
                            // Update max verses
                            if let bookId = getBooks().first(where: { $0.label == book })?.id {
                                let key = "\(bookId)_\(chapter)"
                                versesPerChapter[key] = max(versesPerChapter[key] ?? 0, verse)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func indexVerseLocations() {
        let verses = bibleText.components(separatedBy: "<quotepas>")
        var currentIndex = bibleText.startIndex
        
        for verse in verses {
            if let labelRange = verse.range(of: "<label>"),
               let labelEndRange = verse.range(of: "</label>") {
                let label = String(verse[labelRange.upperBound..<labelEndRange.lowerBound])
                
                if let blockRange = verse.range(of: "<block>"),
                   let blockEndRange = verse.range(of: "</block>") {
                    // Find these ranges in the original text
                    if let originalBlockStart = bibleText[currentIndex...].range(of: "<block>"),
                       let originalBlockEnd = bibleText[originalBlockStart.upperBound...].range(of: "</block>") {
                        // Store the exact location of this verse's content
                        verseLocations[label] = (
                            start: originalBlockStart.upperBound,
                            end: originalBlockEnd.lowerBound
                        )
                    }
                }
            }
            
            // Move the current index past this verse
            if let verseEnd = bibleText[currentIndex...].range(of: "</quotepas>") {
                currentIndex = verseEnd.upperBound
            }
        }
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
        
        let verseLabel = "\(translation)\(bookLabel)\(chapter)v\(verse)"
        
        // Use cached location if available
        if let location = verseLocations[verseLabel] {
            return String(bibleText[location.start..<location.end])
        }
        
        // Fallback to old method if location not found
        if let verseRange = bibleText.range(of: "<quotepas><label>\(verseLabel)</label>"),
           let blockStart = bibleText[verseRange.upperBound...].range(of: "<block>"),
           let blockEnd = bibleText[blockStart.upperBound...].range(of: "</block>") {
            return String(bibleText[blockStart.upperBound..<blockEnd.lowerBound])
        }
        
        return nil
    }
    
    private func loadVerseFromFile(translation: String, book: Int, chapter: Int, verse: Int) -> String? {
        guard isDatabaseReady,
              let bookLabel = getBooks().first(where: { $0.id == book })?.label else {
            return nil
        }
        
        let verseLabel = "\(translation)\(bookLabel)\(chapter)v\(verse)"
        
        // Look for just this specific verse
        if let verseRange = bibleText.range(of: "<quotepas><label>\(verseLabel)</label>"),
           let blockStart = bibleText[verseRange.upperBound...].range(of: "<block>"),
           let blockEnd = bibleText[blockStart.upperBound...].range(of: "</block>") {
            return String(bibleText[blockStart.upperBound..<blockEnd.lowerBound])
        }
        
        return nil
    }
    
    func getMaxVerses(book: Int, chapter: Int) -> Int {
        return Self.verseCountMap[book]?[chapter] ?? 0
    }
    
    func getFormattedVerse(translation: String, book: Int, chapter: Int, verse: Int) -> FormattedVerse {
        guard let rawText = getVerse(translation: translation, book: book, chapter: chapter, verse: verse) else {
            return FormattedVerse(mainText: "", footnotes: [])
        }
        
        // Move all the LaTeX processing code here
        // Return formatted text and footnotes
        return processVerseText(rawText)
    }
    
    private func processVerseText(_ text: String) -> FormattedVerse {
        var mainText = text
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
                let cleanFootnote = processMarkdown(footnoteContent)
                footnotes.append(cleanFootnote)
                mainText.replaceSubrange(footnoteRange, with: "¹")
                currentFootnoteIndex += 1
            }
        }
        
        mainText = processMarkdown(mainText)
        return FormattedVerse(
            mainText: mainText.trimmingCharacters(in: .whitespacesAndNewlines),
            footnotes: footnotes
        )
    }
    
    private func processMarkdown(_ text: String) -> String {
        var processedText = text
        
        // Handle quotes
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
} 
