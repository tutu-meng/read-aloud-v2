//
//  PaginationStore.swift
//  ReadAloudApp
//
//  DAO for pagination cache using DatabaseService (SQLite).
//

import Foundation
import CoreGraphics
import SQLite3

// Swift does not expose SQLITE_TRANSIENT by default; define it here for bind_text
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class PaginationStore {
    static let shared = PaginationStore()
    private let db = DatabaseService.shared

    private init() {}

    func upsertBatch(bookHash: String,
                     settingsKey: String,
                     viewSize: CGSize,
                     pages: [PaginationCache.PageRange],
                     lastProcessedIndex: Int,
                     isComplete: Bool,
                     totalPages: Int?) throws {
        try db.inTransaction { dbh in
            // Insert/Update pages
            let insertPageSQL = """
            INSERT INTO page_cache (
              book_hash, settings_key, page_number,
              start_index, end_index, content, last_updated
            ) VALUES (?, ?, ?, ?, ?, ?, unixepoch())
            ON CONFLICT(book_hash, settings_key, page_number)
            DO UPDATE SET
              start_index=excluded.start_index,
              end_index=excluded.end_index,
              content=excluded.content,
              last_updated=unixepoch();
            """
            var pageStmt: OpaquePointer?
            guard sqlite3_prepare_v2(dbh, insertPageSQL, -1, &pageStmt, nil) == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(dbh))
                throw NSError(domain: "SQLite", code: 10, userInfo: [NSLocalizedDescriptionKey: "prepare page: \(msg)"])
            }
            defer { sqlite3_finalize(pageStmt) }

            for p in pages {
                sqlite3_reset(pageStmt)
                sqlite3_clear_bindings(pageStmt)
                sqlite3_bind_text(pageStmt, 1, (bookHash as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(pageStmt, 2, (settingsKey as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(pageStmt, 3, Int32(p.pageNumber))
                sqlite3_bind_int(pageStmt, 4, Int32(p.startIndex))
                sqlite3_bind_int(pageStmt, 5, Int32(p.endIndex))
                if let cstr = (p.content as NSString).utf8String { sqlite3_bind_text(pageStmt, 6, cstr, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(pageStmt, 6) }
                guard sqlite3_step(pageStmt) == SQLITE_DONE else {
                    let msg = String(cString: sqlite3_errmsg(dbh))
                    throw NSError(domain: "SQLite", code: 11, userInfo: [NSLocalizedDescriptionKey: "step page: \(msg)"])
                }
            }

            // Insert/Update meta
            let insertMetaSQL = """
            INSERT INTO page_meta (
              book_hash, settings_key, last_processed_index,
              is_complete, total_pages, view_width, view_height, last_updated
            ) VALUES (?, ?, ?, ?, ?, ?, ?, unixepoch())
            ON CONFLICT(book_hash, settings_key)
            DO UPDATE SET
              last_processed_index=excluded.last_processed_index,
              is_complete=excluded.is_complete,
              total_pages=COALESCE(excluded.total_pages, page_meta.total_pages),
              view_width=excluded.view_width,
              view_height=excluded.view_height,
              last_updated=unixepoch();
            """
            var metaStmt: OpaquePointer?
            guard sqlite3_prepare_v2(dbh, insertMetaSQL, -1, &metaStmt, nil) == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(dbh))
                throw NSError(domain: "SQLite", code: 12, userInfo: [NSLocalizedDescriptionKey: "prepare meta: \(msg)"])
            }
            defer { sqlite3_finalize(metaStmt) }
            sqlite3_bind_text(metaStmt, 1, (bookHash as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(metaStmt, 2, (settingsKey as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(metaStmt, 3, Int32(lastProcessedIndex))
            sqlite3_bind_int(metaStmt, 4, isComplete ? 1 : 0)
            if let totalPages = totalPages { sqlite3_bind_int(metaStmt, 5, Int32(totalPages)) } else { sqlite3_bind_null(metaStmt, 5) }
            sqlite3_bind_double(metaStmt, 6, Double(viewSize.width))
            sqlite3_bind_double(metaStmt, 7, Double(viewSize.height))
            guard sqlite3_step(metaStmt) == SQLITE_DONE else {
                let msg = String(cString: sqlite3_errmsg(dbh))
                throw NSError(domain: "SQLite", code: 13, userInfo: [NSLocalizedDescriptionKey: "step meta: \(msg)"])
            }
        }
    }

    func fetchCache(bookHash: String, settingsKey: String, fallbackViewSize: CGSize) throws -> PaginationCache? {
        return try db.perform { dbh in
            // Read meta
            let metaSQL = "SELECT last_processed_index, is_complete, total_pages, view_width, view_height FROM page_meta WHERE book_hash=? AND settings_key=?;"
            var metaStmt: OpaquePointer?
            guard sqlite3_prepare_v2(dbh, metaSQL, -1, &metaStmt, nil) == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(dbh))
                throw NSError(domain: "SQLite", code: 14, userInfo: [NSLocalizedDescriptionKey: "prepare select meta: \(msg)"])
            }
            defer { sqlite3_finalize(metaStmt) }
            sqlite3_bind_text(metaStmt, 1, (bookHash as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(metaStmt, 2, (settingsKey as NSString).utf8String, -1, SQLITE_TRANSIENT)
            var lastProcessed = 0
            var isComplete = false
            var totalPages: Int? = nil
            var viewW: Double = 0
            var viewH: Double = 0
            if sqlite3_step(metaStmt) == SQLITE_ROW {
                lastProcessed = Int(sqlite3_column_int(metaStmt, 0))
                isComplete = sqlite3_column_int(metaStmt, 1) != 0
                if sqlite3_column_type(metaStmt, 2) != SQLITE_NULL { totalPages = Int(sqlite3_column_int(metaStmt, 2)) }
                if sqlite3_column_type(metaStmt, 3) != SQLITE_NULL { viewW = sqlite3_column_double(metaStmt, 3) }
                if sqlite3_column_type(metaStmt, 4) != SQLITE_NULL { viewH = sqlite3_column_double(metaStmt, 4) }
            } else {
                // No meta: check if any pages exist
                let countSQL = "SELECT COUNT(1) FROM page_cache WHERE book_hash=? AND settings_key=?;"
                var cntStmt: OpaquePointer?
                var hasPages = false
                if sqlite3_prepare_v2(dbh, countSQL, -1, &cntStmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(cntStmt, 1, (bookHash as NSString).utf8String, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(cntStmt, 2, (settingsKey as NSString).utf8String, -1, SQLITE_TRANSIENT)
                    if sqlite3_step(cntStmt) == SQLITE_ROW { hasPages = sqlite3_column_int(cntStmt, 0) > 0 }
                }
                sqlite3_finalize(cntStmt)
                if !hasPages { return nil }
            }

            // Read pages
            let pagesSQL = "SELECT page_number, content, start_index, end_index FROM page_cache WHERE book_hash=? AND settings_key=? ORDER BY page_number;"
            var pagesStmt: OpaquePointer?
            guard sqlite3_prepare_v2(dbh, pagesSQL, -1, &pagesStmt, nil) == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(dbh))
                throw NSError(domain: "SQLite", code: 15, userInfo: [NSLocalizedDescriptionKey: "prepare select pages: \(msg)"])
            }
            defer { sqlite3_finalize(pagesStmt) }
            sqlite3_bind_text(pagesStmt, 1, (bookHash as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(pagesStmt, 2, (settingsKey as NSString).utf8String, -1, SQLITE_TRANSIENT)
            var pages: [PaginationCache.PageRange] = []
            while sqlite3_step(pagesStmt) == SQLITE_ROW {
                let pageNumber = Int(sqlite3_column_int(pagesStmt, 0))
                let contentC = sqlite3_column_text(pagesStmt, 1)
                let content = contentC != nil ? String(cString: contentC!) : ""
                let startIdx = Int(sqlite3_column_int(pagesStmt, 2))
                let endIdx = Int(sqlite3_column_int(pagesStmt, 3))
                pages.append(PaginationCache.PageRange(pageNumber: pageNumber, content: content, startIndex: startIdx, endIndex: endIdx))
            }

            let size = (viewW > 0 && viewH > 0) ? CGSize(width: viewW, height: viewH) : fallbackViewSize
            return PaginationCache(bookHash: bookHash,
                                   settingsKey: settingsKey,
                                   viewSize: size,
                                   pages: pages,
                                   lastProcessedIndex: lastProcessed,
                                   isComplete: isComplete,
                                   lastUpdated: Date())
        }
    }

    /// Fetch a single page by page number (1-based). Returns nil if not found.
    func fetchPage(bookHash: String, settingsKey: String, pageNumber: Int) throws -> PaginationCache.PageRange? {
        return try db.perform { dbh in
            let sql = "SELECT page_number, content, start_index, end_index FROM page_cache WHERE book_hash=? AND settings_key=? AND page_number=?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(dbh, sql, -1, &stmt, nil) == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(dbh))
                throw NSError(domain: "SQLite", code: 18, userInfo: [NSLocalizedDescriptionKey: "prepare fetchPage: \(msg)"])
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (bookHash as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (settingsKey as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 3, Int32(pageNumber))
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            let pn = Int(sqlite3_column_int(stmt, 0))
            let contentC = sqlite3_column_text(stmt, 1)
            let content = contentC != nil ? String(cString: contentC!) : ""
            let startIdx = Int(sqlite3_column_int(stmt, 2))
            let endIdx = Int(sqlite3_column_int(stmt, 3))
            return PaginationCache.PageRange(pageNumber: pn, content: content, startIndex: startIdx, endIndex: endIdx)
        }
    }

    /// Fetch page count for a (bookHash, settingsKey) pair.
    func fetchPageCount(bookHash: String, settingsKey: String) throws -> Int {
        return try db.perform { dbh in
            let sql = "SELECT COUNT(1) FROM page_cache WHERE book_hash=? AND settings_key=?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(dbh, sql, -1, &stmt, nil) == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(dbh))
                throw NSError(domain: "SQLite", code: 19, userInfo: [NSLocalizedDescriptionKey: "prepare fetchPageCount: \(msg)"])
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (bookHash as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (settingsKey as NSString).utf8String, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
        }
    }

    /// Fetch only metadata (no page content). Returns nil if no meta row exists.
    func fetchMeta(bookHash: String, settingsKey: String) throws -> (isComplete: Bool, totalPages: Int?, lastProcessedIndex: Int)? {
        return try db.perform { dbh in
            let sql = "SELECT last_processed_index, is_complete, total_pages FROM page_meta WHERE book_hash=? AND settings_key=?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(dbh, sql, -1, &stmt, nil) == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(dbh))
                throw NSError(domain: "SQLite", code: 20, userInfo: [NSLocalizedDescriptionKey: "prepare fetchMeta: \(msg)"])
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, (bookHash as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (settingsKey as NSString).utf8String, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            let lastProcessed = Int(sqlite3_column_int(stmt, 0))
            let isComplete = sqlite3_column_int(stmt, 1) != 0
            let totalPages: Int? = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 2)) : nil
            return (isComplete: isComplete, totalPages: totalPages, lastProcessedIndex: lastProcessed)
        }
    }

    func deleteAllForBook(_ bookHash: String) throws {
        _ = try db.inTransaction { dbh in
            try exec(dbh, sql: "DELETE FROM page_cache WHERE book_hash=?;", bind: [bookHash])
            try exec(dbh, sql: "DELETE FROM page_meta WHERE book_hash=?;", bind: [bookHash])
        }
    }

    func deleteAllExcept(bookHash: String, keepSettingsKey: String) throws {
        _ = try db.inTransaction { dbh in
            try exec(dbh, sql: "DELETE FROM page_cache WHERE book_hash=? AND settings_key<>?;", bind: [bookHash, keepSettingsKey])
            try exec(dbh, sql: "DELETE FROM page_meta WHERE book_hash=? AND settings_key<>?;", bind: [bookHash, keepSettingsKey])
        }
    }

    // MARK: - Helpers
    private func exec(_ db: OpaquePointer, sql: String, bind: [Any]) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 16, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        defer { sqlite3_finalize(stmt) }
        for (i, val) in bind.enumerated() {
            let idx = Int32(i + 1)
            if let s = val as? String { sqlite3_bind_text(stmt, idx, (s as NSString).utf8String, -1, SQLITE_TRANSIENT) }
            else if let d = val as? Double { sqlite3_bind_double(stmt, idx, d) }
            else if let i = val as? Int { sqlite3_bind_int(stmt, idx, Int32(i)) }
            else { sqlite3_bind_null(stmt, idx) }
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 17, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
}


