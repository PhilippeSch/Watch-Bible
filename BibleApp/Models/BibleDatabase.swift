import Foundation
import SQLite3

class BibleDatabase {
    private var db: OpaquePointer?
    
    struct Translation {
        let id: String
        let name: String
    }
    
    struct Book {
        let number: Int
        let name: String
        let chapters: Int
    }
    
    init() {
        if let path = Bundle.main.path(forResource: "bible", ofType: "db") {
            if sqlite3_open(path, &db) != SQLITE_OK {
                print("Error opening database")
                return
            }
        }
    }
    
    func getTranslations() -> [Translation] {
        var translations: [Translation] = []
        let query = "SELECT id, name FROM translations"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                translations.append(Translation(id: id, name: name))
            }
        }
        sqlite3_finalize(statement)
        return translations
    }
    
    func getVerse(translation: String, book: Int, chapter: Int, verse: Int) -> String? {
        let query = """
            SELECT text FROM verses 
            WHERE translation = ? 
            AND book = ? 
            AND chapter = ? 
            AND verse = ?
        """
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, translation, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(book))
            sqlite3_bind_int(statement, 3, Int32(chapter))
            sqlite3_bind_int(statement, 4, Int32(verse))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let text = String(cString: sqlite3_column_text(statement, 0))
                sqlite3_finalize(statement)
                return text
            }
        }
        sqlite3_finalize(statement)
        return nil
    }
    
    func getMaxVerses(book: Int, chapter: Int) -> Int {
        let query = """
            SELECT MAX(verse) FROM verses 
            WHERE book = ? AND chapter = ?
        """
        var statement: OpaquePointer?
        var maxVerses = 0
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(book))
            sqlite3_bind_int(statement, 2, Int32(chapter))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                maxVerses = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)
        return maxVerses
    }
} 