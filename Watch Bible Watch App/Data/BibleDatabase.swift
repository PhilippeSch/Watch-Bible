import Foundation
import SQLite3

/// Schlanker Wrapper um die sqlite3-C-API. Bewusst ohne GRDB oder SQLite.swift:
/// die Widget-Extension braucht denselben Zugriff, und SPM-Pakete mit C-Target
/// machen dort erfahrungsgemaess Aerger.
///
/// Die Datenbank ist schreibgeschuetzt. Verbindung wird einmal geoeffnet und
/// gehalten, vorbereitete Statements werden zwischengespeichert.
actor BibleDatabase {

    enum DatabaseError: Error, LocalizedError {
        case resourceMissing(String)
        case open(String)
        case prepare(String, sql: String)

        var errorDescription: String? {
            switch self {
            case .resourceMissing(let n): "Datenbank \(n) fehlt im App-Bundle."
            case .open(let m):            "Datenbank liess sich nicht oeffnen: \(m)"
            case .prepare(let m, let s):  "Abfrage fehlerhaft: \(m) — \(s)"
            }
        }
    }

    // nonisolated(unsafe): Swift 6 verbietet sonst den Zugriff aus deinit
    // (isolated deinit braeuchte watchOS 11.4). Unbedenklich — der Actor
    // serialisiert alle Zugriffe, deinit laeuft ohne verbleibende Referenzen.
    private nonisolated(unsafe) let handle: OpaquePointer
    private nonisolated(unsafe) var statements: [String: OpaquePointer] = [:]

    /// Erwartet bible.sqlite als Bundle-Ressource. Target-Membership muss
    /// sowohl die App als auch die Widget-Extension umfassen.
    init(resource: String = "bible", extension ext: String = "sqlite",
         bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: resource, withExtension: ext) else {
            throw DatabaseError.resourceMissing("\(resource).\(ext)")
        }
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unbekannt"
            if let db { sqlite3_close_v2(db) }
            throw DatabaseError.open(msg)
        }
        self.handle = db
        // Leseoptimierung: grosser Page-Cache, kein Temp-Speicher auf Platte.
        sqlite3_exec(db, "PRAGMA cache_size = -4000; PRAGMA temp_store = MEMORY;",
                     nil, nil, nil)
    }

    deinit {
        for (_, stmt) in statements { sqlite3_finalize(stmt) }
        sqlite3_close_v2(handle)
    }

    // MARK: - Abfrage

    /// Fuehrt `sql` mit den gebundenen Werten aus und bildet jede Zeile ab.
    /// Statements werden zwischengespeichert und wiederverwendet.
    func query<T>(_ sql: String, _ bindings: [Int] = [],
                  map: (Row) -> T) throws -> [T] {
        let stmt = try statement(for: sql)
        defer { sqlite3_reset(stmt); sqlite3_clear_bindings(stmt) }
        for (i, value) in bindings.enumerated() {
            sqlite3_bind_int64(stmt, Int32(i + 1), Int64(value))
        }
        var out: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(map(Row(stmt: stmt)))
        }
        return out
    }

    func queryOne<T>(_ sql: String, _ bindings: [Int] = [],
                     map: (Row) -> T) throws -> T? {
        try query(sql, bindings, map: map).first
    }

    private func statement(for sql: String) throws -> OpaquePointer {
        if let cached = statements[sql] { return cached }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt else {
            throw DatabaseError.prepare(String(cString: sqlite3_errmsg(handle)), sql: sql)
        }
        statements[sql] = stmt
        return stmt
    }

    /// Spaltenzugriff einer Ergebniszeile. Nur innerhalb von `map` gueltig.
    struct Row {
        let stmt: OpaquePointer

        func int(_ i: Int32) -> Int { Int(sqlite3_column_int64(stmt, i)) }

        func string(_ i: Int32) -> String {
            guard let c = sqlite3_column_text(stmt, i) else { return "" }
            return String(cString: c)
        }

        func stringOrNil(_ i: Int32) -> String? {
            sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : string(i)
        }
    }
}
