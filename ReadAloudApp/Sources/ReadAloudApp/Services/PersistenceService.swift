//
//  PersistenceService.swift
//  ReadAloudApp
//
//  Created on 2024
//

import Foundation
import CoreGraphics

/// PersistenceService handles saving and loading of application state
/// This service centralizes all persistence logic for UserSettings and ReadingProgress
class PersistenceService {
    
    // MARK: - Constants
    
    /// UserDefaults key for storing UserSettings
    private static let userSettingsKey = "ReadAloudApp.UserSettings"
    
    /// Filename for ReadingProgress storage in Application Support directory
    private static let readingProgressFileName = "ReadingProgress.json"
    
    /// Filename for Book Library storage in Application Support directory
    private static let bookLibraryFileName = "BookLibrary.json"
    
    // MARK: - Shared Instance
    
    /// Shared singleton instance
    static let shared = PersistenceService()
    
    /// Backing store for user defaults (injected for testability)
    private var userDefaults: UserDefaults = .standard
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// TESTING ONLY: Override the UserDefaults store used by this service
    /// - Parameter defaults: The UserDefaults instance to use (e.g., a test suite)
    func overrideUserDefaultsForTesting(_ defaults: UserDefaults) {
        userDefaults = defaults
    }

    // Removed SQLite implementation details; now delegated to DatabaseService/PaginationStore.
    
    // MARK: - UserSettings Persistence
    
    /// Save UserSettings object to UserDefaults by encoding it to JSON
    /// - Parameter settings: The UserSettings object to save
    /// - Throws: PersistenceError if encoding or saving fails
    func saveUserSettings(_ settings: UserSettings) throws {
        debugPrint("💾 PersistenceService: Saving UserSettings")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            
            userDefaults.set(data, forKey: Self.userSettingsKey)
            userDefaults.synchronize()
            
            debugPrint("✅ PersistenceService: UserSettings saved successfully")
        } catch {
            debugPrint("❌ PersistenceService: Failed to save UserSettings: \(error)")
            throw PersistenceError.encodingFailed(underlyingError: error)
        }
    }
    
    /// Load and decode UserSettings object from UserDefaults
    /// - Returns: UserSettings object, or default settings if none found
    /// - Throws: PersistenceError if decoding fails
    func loadUserSettings() throws -> UserSettings {
        debugPrint("📖 PersistenceService: Loading UserSettings")
        
        guard let data = userDefaults.data(forKey: Self.userSettingsKey) else {
            debugPrint("📝 PersistenceService: No saved UserSettings found, returning defaults")
            return UserSettings.default
        }
        
        do {
            let decoder = JSONDecoder()
            let settings = try decoder.decode(UserSettings.self, from: data)
            debugPrint("✅ PersistenceService: UserSettings loaded successfully")
            return settings
        } catch {
            debugPrint("❌ PersistenceService: Failed to decode UserSettings: \(error)")
            debugPrint("📝 PersistenceService: Returning default settings as fallback")
            throw PersistenceError.decodingFailed(underlyingError: error)
        }
    }
    
    // MARK: - ReadingProgress Persistence
    
    /// Save array of ReadingProgress objects to a JSON file in Application Support directory
    /// - Parameter progressArray: Array of ReadingProgress objects to save
    /// - Throws: PersistenceError if encoding, directory creation, or file writing fails
    func saveReadingProgress(_ progressArray: [ReadingProgress]) throws {
        debugPrint("💾 PersistenceService: Saving \(progressArray.count) ReadingProgress entries")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(progressArray)
            
            let fileURL = try getReadingProgressFileURL()
            try data.write(to: fileURL)
            
            debugPrint("✅ PersistenceService: ReadingProgress saved to \(fileURL.path)")
        } catch {
            debugPrint("❌ PersistenceService: Failed to save ReadingProgress: \(error)")
            throw PersistenceError.savingFailed(underlyingError: error)
        }
    }
    
    /// Load and decode array of ReadingProgress objects from JSON file
    /// - Returns: Array of ReadingProgress objects, empty array if none found
    /// - Throws: PersistenceError if decoding fails
    func loadReadingProgress() throws -> [ReadingProgress] {
        debugPrint("📖 PersistenceService: Loading ReadingProgress")
        
        let fileURL = try getReadingProgressFileURL()
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            debugPrint("📝 PersistenceService: No ReadingProgress file found, returning empty array")
            return []
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let progressArray = try decoder.decode([ReadingProgress].self, from: data)
            debugPrint("✅ PersistenceService: Loaded \(progressArray.count) ReadingProgress entries")
            return progressArray
        } catch {
            debugPrint("❌ PersistenceService: Failed to decode ReadingProgress: \(error)")
            throw PersistenceError.decodingFailed(underlyingError: error)
        }
    }

    // MARK: - Book Library Persistence

    /// Save array of Book objects to JSON using a container-agnostic relative path under Documents
    /// - Parameter books: Array of Book objects to save
    /// - Throws: PersistenceError if encoding, directory creation, or file writing fails
    func saveBookLibrary(_ books: [Book]) throws {
        debugPrint("💾 PersistenceService: Saving \(books.count) Book entries")
        
        struct PersistedBook: Codable {
            let id: UUID
            let title: String
            let relativePath: String
            let contentHash: String
            let importedDate: Date
            let fileSize: Int64
            let textEncoding: String
        }
        
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let docsPath = docs.path.hasSuffix("/") ? docs.path : docs.path + "/"
            let mapped = books.map { b -> PersistedBook in
                let fullPath = b.fileURL.path
                let rel = fullPath.hasPrefix(docsPath) ? String(fullPath.dropFirst(docsPath.count)) : b.fileURL.lastPathComponent
                return PersistedBook(
                    id: b.id,
                    title: b.title,
                    relativePath: rel,
                    contentHash: b.contentHash,
                    importedDate: b.importedDate,
                    fileSize: b.fileSize,
                    textEncoding: b.textEncoding
                )
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(mapped)
            
            let fileURL = try getBookLibraryFileURL()
            try data.write(to: fileURL)
            
            debugPrint("✅ PersistenceService: Book library saved to \(fileURL.path)")
        } catch {
            debugPrint("❌ PersistenceService: Failed to save book library: \(error)")
            throw PersistenceError.savingFailed(underlyingError: error)
        }
    }

    /// Load and decode array of Book objects from JSON file (expects relative paths).
    /// If the file contains legacy format (with `fileURL` instead of `relativePath`),
    /// it will be migrated to the new format automatically.
    /// - Returns: Array of Book objects, empty array if none found
    /// - Throws: PersistenceError if decoding fails
    func loadBookLibrary() throws -> [Book] {
        debugPrint("📖 PersistenceService: Loading book library")

        let fileURL = try getBookLibraryFileURL()

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            debugPrint("📝 PersistenceService: No book library file found, returning empty array")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            struct PersistedBook: Codable {
                let id: UUID
                let title: String
                let relativePath: String
                let contentHash: String
                let importedDate: Date
                let fileSize: Int64
                let textEncoding: String
            }

            // Try current format first
            if let persisted = try? decoder.decode([PersistedBook].self, from: data) {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let books: [Book] = persisted.map { p in
                    let url = docs.appendingPathComponent(p.relativePath)
                    return Book(
                        id: p.id,
                        title: p.title,
                        fileURL: url,
                        contentHash: p.contentHash,
                        importedDate: p.importedDate,
                        fileSize: p.fileSize,
                        textEncoding: p.textEncoding
                    )
                }
                debugPrint("✅ PersistenceService: Loaded \(books.count) Book entries")
                return books
            }

            // Fall back to legacy format (fileURL instead of relativePath)
            struct LegacyBook: Codable {
                let id: UUID
                let title: String
                let fileURL: URL
                let contentHash: String
                let importedDate: Date
                let fileSize: Int64
                let textEncoding: String
            }

            let legacy = try decoder.decode([LegacyBook].self, from: data)
            debugPrint("⚠️ PersistenceService: Detected legacy BookLibrary format, migrating \(legacy.count) entries")

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let books: [Book] = legacy.map { l in
                return Book(
                    id: l.id,
                    title: l.title,
                    fileURL: l.fileURL,
                    contentHash: l.contentHash,
                    importedDate: l.importedDate,
                    fileSize: l.fileSize,
                    textEncoding: l.textEncoding
                )
            }

            // Re-save in new format to complete migration
            try saveBookLibrary(books)
            debugPrint("✅ PersistenceService: Migration complete, saved \(books.count) books in new format")

            return books
        } catch {
            debugPrint("❌ PersistenceService: Failed to decode book library: \(error)")
            throw PersistenceError.decodingFailed(underlyingError: error)
        }
    }

    // MARK: - Pagination Cache APIs (SQLite-backed)
    func loadPaginationCache(bookHash: String, settingsKey: String) throws -> PaginationCache? {
        let fallback = loadLastViewSize()
        return try PaginationStore.shared.fetchCache(bookHash: bookHash, settingsKey: settingsKey, fallbackViewSize: fallback)
    }

    func savePaginationCache(_ cache: PaginationCache) throws {
        try PaginationStore.shared.upsertBatch(
            bookHash: cache.bookHash,
            settingsKey: cache.settingsKey,
            viewSize: cache.viewSize,
            pages: cache.pages,
            lastProcessedIndex: cache.lastProcessedIndex,
            isComplete: cache.isComplete,
            totalPages: cache.isComplete ? cache.pages.count : nil
        )
    }

    /// Incrementally upsert only the provided pages for a given (bookHash, settingsKey)
    func upsertPaginationBatch(bookHash: String,
                               settingsKey: String,
                               viewSize: CGSize,
                               pages: [PaginationCache.PageRange],
                               lastProcessedIndex: Int,
                               isComplete: Bool,
                               totalPages: Int?) throws {
        try PaginationStore.shared.upsertBatch(
            bookHash: bookHash,
            settingsKey: settingsKey,
            viewSize: viewSize,
            pages: pages,
            lastProcessedIndex: lastProcessedIndex,
            isComplete: isComplete,
            totalPages: totalPages
        )
    }

    /// Remove all pagination caches for a given book
    func clearPaginationCache(for bookHash: String) {
        do { try PaginationStore.shared.deleteAllForBook(bookHash) }
        catch { debugPrint("⚠️ PersistenceService: Failed to clear pagination cache for book \(bookHash): \(error)") }
    }

    /// Remove all pagination caches for a book except the one matching keepSettingsKey
    func cleanupPaginationCaches(for bookHash: String, keepSettingsKey: String) {
        do { try PaginationStore.shared.deleteAllExcept(bookHash: bookHash, keepSettingsKey: keepSettingsKey) }
        catch { debugPrint("⚠️ PersistenceService: Failed to cleanup caches for book \(bookHash): \(error)") }
    }

    /// Validate that all books in the library still have valid file URLs
    /// - Parameter books: Array of books to validate
    /// - Returns: Array of books with valid file URLs (removes books whose files no longer exist)
    func validateBookLibrary(_ books: [Book]) -> [Book] {
        debugPrint("🔍 PersistenceService: Validating \(books.count) books in library")
        
        let validBooks = books.filter { book in
            let fileExists = FileManager.default.fileExists(atPath: book.fileURL.path)
            if !fileExists {
                debugPrint("⚠️ PersistenceService: Book file no longer exists: \(book.title) at \(book.fileURL.path)")
            }
            return fileExists
        }
        
        if validBooks.count != books.count {
            debugPrint("📚 PersistenceService: Filtered library from \(books.count) to \(validBooks.count) valid books")
        }
        
        return validBooks
    }
    
    // MARK: - Helper Methods
    
    /// Get the URL for the ReadingProgress JSON file in Application Support directory
    /// - Returns: URL to the ReadingProgress file
    /// - Throws: PersistenceError if Application Support directory cannot be accessed or created
    private func getReadingProgressFileURL() throws -> URL {
        let fileManager = FileManager.default
        
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw PersistenceError.directoryAccessFailed
        }
        
        // Create app-specific directory in Application Support
        let appDirectory = appSupportURL.appendingPathComponent("ReadAloudApp")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDirectory.path) {
            do {
                try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
                debugPrint("📁 PersistenceService: Created Application Support directory: \(appDirectory.path)")
            } catch {
                debugPrint("❌ PersistenceService: Failed to create directory: \(error)")
                throw PersistenceError.directoryCreationFailed(underlyingError: error)
            }
        }
        
        return appDirectory.appendingPathComponent(Self.readingProgressFileName)
    }

    /// Get the URL for the Book Library JSON file in Application Support directory
    /// - Returns: URL to the Book Library file
    /// - Throws: PersistenceError if Application Support directory cannot be accessed or created
    private func getBookLibraryFileURL() throws -> URL {
        let fileManager = FileManager.default
        
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw PersistenceError.directoryAccessFailed
        }
        
        // Create app-specific directory in Application Support
        let appDirectory = appSupportURL.appendingPathComponent("ReadAloudApp")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDirectory.path) {
            do {
                try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
                debugPrint("📁 PersistenceService: Created Application Support directory: \(appDirectory.path)")
            } catch {
                debugPrint("❌ PersistenceService: Failed to create directory: \(error)")
                throw PersistenceError.directoryCreationFailed(underlyingError: error)
            }
        }
        
        return appDirectory.appendingPathComponent(Self.bookLibraryFileName)
    }
    
    /// Get the current Application Support directory path for debugging
    /// - Returns: String path to the Application Support directory
    func getApplicationSupportPath() -> String? {
        return try? getReadingProgressFileURL().deletingLastPathComponent().path
    }
    
    // MARK: - View Size Persistence (minimal API for ReaderViewModel)
    func saveLastViewSize(_ size: CGSize) {
        let dict: [String: CGFloat] = ["width": size.width, "height": size.height]
        userDefaults.set(dict, forKey: "ReadAloudApp.LastViewSize")
    }
    
    func loadLastViewSize() -> CGSize {
        if let dict = userDefaults.dictionary(forKey: "ReadAloudApp.LastViewSize") as? [String: CGFloat],
           let w = dict["width"], let h = dict["height"] {
            return CGSize(width: w, height: h)
        }
        return CGSize(width: 390, height: 844)
    }
}

// MARK: - PersistenceError

/// Errors that can occur during persistence operations
enum PersistenceError: LocalizedError {
    case encodingFailed(underlyingError: Error)
    case decodingFailed(underlyingError: Error)
    case savingFailed(underlyingError: Error)
    case directoryAccessFailed
    case directoryCreationFailed(underlyingError: Error)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed(let error):
            return "Failed to encode data for persistence: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode persisted data: \(error.localizedDescription)"
        case .savingFailed(let error):
            return "Failed to save data to disk: \(error.localizedDescription)"
        case .directoryAccessFailed:
            return "Could not access Application Support directory"
        case .directoryCreationFailed(let error):
            return "Failed to create Application Support directory: \(error.localizedDescription)"
        }
    }
} 