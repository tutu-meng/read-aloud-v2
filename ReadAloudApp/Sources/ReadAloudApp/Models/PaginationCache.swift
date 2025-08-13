//
//  PaginationCache.swift
//  ReadAloudApp
//
//  Created on 2025-01-12
//  PGN-9: Decoupled Background Pagination
//

import Foundation
import CoreGraphics

/// Cache model for storing pagination results
struct PaginationCache: Codable {
    /// SHA256 hash of the book content
    let bookHash: String
    
    /// Combined settings key for cache validation
    let settingsKey: String
    
    /// View size used for pagination
    let viewSize: CGSize
    
    /// Array of paginated page ranges
    let pages: [PageRange]
    
    /// Last processed character index
    let lastProcessedIndex: Int
    
    /// Whether pagination is complete
    let isComplete: Bool
    
    /// When this cache was last updated
    let lastUpdated: Date
    
    /// Represents a single page's content and range
    struct PageRange: Codable {
        /// The actual text content of the page
        let content: String
        
        /// Starting character index in the full text
        let startIndex: Int
        
        /// Ending character index in the full text
        let endIndex: Int
    }
    
    /// Generate a unique cache key from book hash, settings, and view size
    /// - Parameters:
    ///   - bookHash: SHA256 hash of the book content
    ///   - settings: User settings affecting pagination
    ///   - viewSize: Size of the view area
    /// - Returns: Unique string key for this configuration
    static func cacheKey(bookHash: String, settings: UserSettings, viewSize: CGSize) -> String {
        let components = [
            bookHash,
            settings.fontName,
            "\(settings.fontSize)",
            "\(settings.lineSpacing)",
            "\(Int(viewSize.width))x\(Int(viewSize.height))",
            // Layout version to invalidate caches when drawable metrics change
            "pad16v1"
        ]
        return components.joined(separator: "-")
    }
    
    /// Check if this cache is valid for the given settings and view size
    /// - Parameters:
    ///   - settings: Current user settings
    ///   - viewSize: Current view size
    /// - Returns: true if cache is still valid
    func isValid(for settings: UserSettings, viewSize: CGSize) -> Bool {
        let currentKey = PaginationCache.cacheKey(
            bookHash: bookHash,
            settings: settings,
            viewSize: viewSize
        )
        return currentKey == settingsKey
    }
}

// MARK: - Codable Support for CGSize

extension PaginationCache {
    enum CodingKeys: String, CodingKey {
        case bookHash
        case settingsKey
        case viewSize
        case pages
        case lastProcessedIndex
        case isComplete
        case lastUpdated
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookHash = try container.decode(String.self, forKey: .bookHash)
        settingsKey = try container.decode(String.self, forKey: .settingsKey)
        
        // Decode CGSize manually
        let sizeDict = try container.decode([String: CGFloat].self, forKey: .viewSize)
        viewSize = CGSize(
            width: sizeDict["width"] ?? 0,
            height: sizeDict["height"] ?? 0
        )
        
        pages = try container.decode([PageRange].self, forKey: .pages)
        lastProcessedIndex = try container.decode(Int.self, forKey: .lastProcessedIndex)
        isComplete = try container.decode(Bool.self, forKey: .isComplete)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookHash, forKey: .bookHash)
        try container.encode(settingsKey, forKey: .settingsKey)
        
        // Encode CGSize manually
        let sizeDict = [
            "width": viewSize.width,
            "height": viewSize.height
        ]
        try container.encode(sizeDict, forKey: .viewSize)
        
        try container.encode(pages, forKey: .pages)
        try container.encode(lastProcessedIndex, forKey: .lastProcessedIndex)
        try container.encode(isComplete, forKey: .isComplete)
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }
}
