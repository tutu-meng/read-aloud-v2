//
//  PersistenceService.swift
//  ReadAloudApp
//
//  Created on 2024
//

import Foundation

/// PersistenceService handles saving and loading of application state
/// This service centralizes all persistence logic for UserSettings and ReadingProgress
class PersistenceService {
    
    // MARK: - Constants
    
    /// UserDefaults key for storing UserSettings
    private static let userSettingsKey = "ReadAloudApp.UserSettings"
    
    /// Filename for ReadingProgress storage in Application Support directory
    private static let readingProgressFileName = "ReadingProgress.json"
    
    // MARK: - Shared Instance
    
    /// Shared singleton instance
    static let shared = PersistenceService()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
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
            
            UserDefaults.standard.set(data, forKey: Self.userSettingsKey)
            UserDefaults.standard.synchronize()
            
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
        
        guard let data = UserDefaults.standard.data(forKey: Self.userSettingsKey) else {
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
    
    /// Get the current Application Support directory path for debugging
    /// - Returns: String path to the Application Support directory
    func getApplicationSupportPath() -> String? {
        return try? getReadingProgressFileURL().deletingLastPathComponent().path
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