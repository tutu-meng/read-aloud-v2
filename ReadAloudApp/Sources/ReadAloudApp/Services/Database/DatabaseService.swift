//
//  DatabaseService.swift
//  ReadAloudApp
//
//  Centralized SQLite access for persistence. Owns the connection, pragmas, and schema migrations.
//

import Foundation
import SQLite3

final class DatabaseService {
    static let shared = DatabaseService()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.readAloud.database", qos: .utility)

    private init() {}

    // MARK: - Public API

    func perform<T>(_ work: (OpaquePointer) throws -> T) throws -> T {
        try openIfNeeded()
        guard let db = db else { fatalError("Database not opened") }
        var result: T!
        var caughtError: Error?
        queue.sync {
            do { result = try work(db) }
            catch { caughtError = error }
        }
        if let e = caughtError { throw e }
        return result
    }

    func inTransaction<T>(_ work: (OpaquePointer) throws -> T) throws -> T {
        try openIfNeeded()
        guard let db = db else { fatalError("Database not opened") }
        var result: T!
        var caughtError: Error?
        queue.sync {
            do {
                try exec(db, sql: "BEGIN IMMEDIATE;")
                result = try work(db)
                try exec(db, sql: "COMMIT;")
            } catch {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                caughtError = error
            }
        }
        if let e = caughtError { throw e }
        return result
    }

    // MARK: - Private

    private func openIfNeeded() throws {
        if db != nil { return }
        let dbURL = try getDBURL()
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbURL.path, &handle, flags, nil) != SQLITE_OK {
            let msg = handle != nil ? String(cString: sqlite3_errmsg(handle)) : "unknown"
            sqlite3_close(handle)
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open DB: \(msg)"])
        }
        guard let opened = handle else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open DB: nil handle"])
        }
        db = opened
        _ = sqlite3_busy_timeout(opened, 3000)
        try exec(opened, sql: "PRAGMA journal_mode=WAL;")
        try exec(opened, sql: "PRAGMA synchronous=NORMAL;")
        try migrateIfNeeded(opened)
    }

    private func migrateIfNeeded(_ db: OpaquePointer) throws {
        let createPageCache = """
        CREATE TABLE IF NOT EXISTS page_cache (
          book_hash    TEXT NOT NULL,
          settings_key TEXT NOT NULL,
          page_number  INTEGER NOT NULL,
          start_index  INTEGER NOT NULL,
          end_index    INTEGER NOT NULL,
          content      TEXT NULL,
          last_updated REAL NOT NULL DEFAULT (strftime('%s','now')),
          PRIMARY KEY (book_hash, settings_key, page_number)
        );
        """
        let createPageMeta = """
        CREATE TABLE IF NOT EXISTS page_meta (
          book_hash            TEXT NOT NULL,
          settings_key         TEXT NOT NULL,
          last_processed_index INTEGER NOT NULL,
          is_complete          INTEGER NOT NULL DEFAULT 0,
          total_pages          INTEGER NULL,
          view_width           REAL NULL,
          view_height          REAL NULL,
          last_updated         REAL NOT NULL DEFAULT (strftime('%s','now')),
          PRIMARY KEY (book_hash, settings_key)
        );
        """
        let idxLookup = """
        CREATE INDEX IF NOT EXISTS idx_cache_lookup
          ON page_cache(book_hash, settings_key, page_number);
        """
        try exec(db, sql: createPageCache)
        try exec(db, sql: createPageMeta)
        try exec(db, sql: idxLookup)
    }

    private func exec(_ db: OpaquePointer, sql: String) throws {
        var err: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err != nil ? String(cString: err!) : "unknown"
            if let err = err { sqlite3_free(err) }
            throw NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private func getDBURL() throws -> URL {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "Persistence", code: 3, userInfo: [NSLocalizedDescriptionKey: "No Application Support directory"])
        }
        let appDirectory = appSupportURL.appendingPathComponent("ReadAloudApp")
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        return appDirectory.appendingPathComponent("pagination.sqlite")
    }
}


