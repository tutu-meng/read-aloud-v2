//
//  LayoutCache.swift
//  ReadAloudApp
//
//  Created on PGN-1 implementation
//

import Foundation
import CoreGraphics

/// LayoutCache is responsible for storing and retrieving calculated page layouts
/// This prevents redundant, computationally expensive layout calculations
class LayoutCache {
    
    // MARK: - Types
    
    /// Unique identifier for a layout configuration
    struct LayoutCacheKey: Hashable {
        let fontName: String
        let fontSize: CGFloat
        let lineSpacing: CGFloat
        let viewWidth: CGFloat
        let viewHeight: CGFloat
        let contentHash: Int
        
        /// Create a cache key from settings and view dimensions
        init(userSettings: UserSettings, viewSize: CGSize, contentHash: Int) {
            self.fontName = userSettings.fontName
            self.fontSize = userSettings.fontSize
            self.lineSpacing = userSettings.lineSpacing
            self.viewWidth = viewSize.width
            self.viewHeight = viewSize.height
            self.contentHash = contentHash
        }
    }
    
    /// Cached layout information for a specific configuration
    struct LayoutInfo {
        let pageCount: Int
        let pageRanges: [NSRange]
        let timestamp: Date
        
        init(pageCount: Int, pageRanges: [NSRange]) {
            self.pageCount = pageCount
            self.pageRanges = pageRanges
            self.timestamp = Date()
        }
    }
    
    // MARK: - Properties
    
    /// Cache storage for calculated layouts
    private var cache: [LayoutCacheKey: LayoutInfo] = [:]
    
    /// Maximum number of cached layouts to prevent memory bloat
    private let maxCacheSize: Int = 50
    
    /// Maximum age of cached layouts in seconds
    private let maxCacheAge: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    init() {
        debugPrint("🗂️ LayoutCache: Initializing cache system")
    }
    
    // MARK: - Public Methods
    
    /// Store a calculated layout in the cache
    /// - Parameters:
    ///   - userSettings: The user settings used for layout calculation
    ///   - viewSize: The view dimensions used for layout calculation
    ///   - contentHash: Hash of the content that was laid out
    ///   - pageCount: Total number of pages calculated
    ///   - pageRanges: Array of NSRange objects representing each page's character range
    func storeLayout(
        userSettings: UserSettings,
        viewSize: CGSize,
        contentHash: Int,
        pageCount: Int,
        pageRanges: [NSRange]
    ) {
        let key = LayoutCacheKey(userSettings: userSettings, viewSize: viewSize, contentHash: contentHash)
        let layoutInfo = LayoutInfo(pageCount: pageCount, pageRanges: pageRanges)
        
        cache[key] = layoutInfo
        
        debugPrint("🗂️ LayoutCache: Stored layout for \(pageCount) pages")
        
        // Clean up old entries if cache is getting too large
        cleanupCacheIfNeeded()
    }
    
    /// Retrieve a cached layout if it exists and is still valid
    /// - Parameters:
    ///   - userSettings: The user settings for layout calculation
    ///   - viewSize: The view dimensions for layout calculation
    ///   - contentHash: Hash of the content to be laid out
    /// - Returns: LayoutInfo if found and valid, nil otherwise
    func retrieveLayout(
        userSettings: UserSettings,
        viewSize: CGSize,
        contentHash: Int
    ) -> LayoutInfo? {
        let key = LayoutCacheKey(userSettings: userSettings, viewSize: viewSize, contentHash: contentHash)
        
        guard let layoutInfo = cache[key] else {
            debugPrint("🗂️ LayoutCache: No cached layout found for key")
            return nil
        }
        
        // Check if the cached layout is still valid
        let age = Date().timeIntervalSince(layoutInfo.timestamp)
        if age > maxCacheAge {
            debugPrint("🗂️ LayoutCache: Cached layout expired (age: \(age)s)")
            cache.removeValue(forKey: key)
            return nil
        }
        
        debugPrint("🗂️ LayoutCache: Retrieved cached layout for \(layoutInfo.pageCount) pages")
        return layoutInfo
    }
    
    /// Clear all cached layouts
    func clearCache() {
        cache.removeAll()
        debugPrint("🗂️ LayoutCache: Cleared all cached layouts")
    }
    
    /// Get the current number of cached layouts
    /// - Returns: Number of cached layouts
    func cacheCount() -> Int {
        return cache.count
    }
    
    /// Check if a specific layout is cached
    /// - Parameters:
    ///   - userSettings: The user settings for layout calculation
    ///   - viewSize: The view dimensions for layout calculation
    ///   - contentHash: Hash of the content to be laid out
    /// - Returns: True if the layout is cached and valid, false otherwise
    func hasValidLayout(
        userSettings: UserSettings,
        viewSize: CGSize,
        contentHash: Int
    ) -> Bool {
        return retrieveLayout(userSettings: userSettings, viewSize: viewSize, contentHash: contentHash) != nil
    }
    
    // MARK: - Private Methods
    
    /// Clean up old or excess cache entries
    private func cleanupCacheIfNeeded() {
        // Remove expired entries
        let now = Date()
        let expiredKeys = cache.compactMap { key, value in
            let age = now.timeIntervalSince(value.timestamp)
            return age > maxCacheAge ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
        
        // If still too many entries, remove oldest ones
        if cache.count > maxCacheSize {
            let sortedEntries = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let entriesToRemove = sortedEntries.prefix(cache.count - maxCacheSize)
            
            for (key, _) in entriesToRemove {
                cache.removeValue(forKey: key)
            }
            
            debugPrint("🗂️ LayoutCache: Cleaned up \(entriesToRemove.count) old entries")
        }
    }
    
    // MARK: - Deinit
    
    deinit {
        debugPrint("♻️ LayoutCache: Deinitializing")
    }
} 