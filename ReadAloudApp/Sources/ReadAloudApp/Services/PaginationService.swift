//
//  PaginationService.swift
//  ReadAloudApp
//
//  Created on 2024
//

import Foundation
import SwiftUI

/// PaginationService handles text layout and pagination calculations
/// This service is responsible for calculating page breaks based on text content,
/// font settings, and view dimensions
class PaginationService {
    
    // MARK: - Properties
    
    /// Cache for paginated content to avoid recalculation
    private var paginationCache: [String: [String]] = [:]
    
    /// Current user settings affecting layout
    private var currentSettings: UserSettings?
    
    /// Current view dimensions
    private var currentViewSize: CGSize?
    
    // MARK: - Initialization
    
    init() {
        debugPrint("📄 PaginationService: Initializing")
    }
    
    // MARK: - Public Methods
    
    /// Invalidate the pagination cache when settings change
    /// This method is called when layout-affecting properties change
    func invalidateCache() {
        debugPrint("🗑️ PaginationService: Invalidating pagination cache")
        paginationCache.removeAll()
        currentSettings = nil
        currentViewSize = nil
    }
    
    /// Paginate text content based on current settings and view dimensions
    /// - Parameters:
    ///   - content: The full text content to paginate
    ///   - settings: User settings affecting layout (font, size, spacing)
    ///   - viewSize: Available view dimensions for text
    /// - Returns: Array of paginated text chunks
    func paginateText(content: String, settings: UserSettings, viewSize: CGSize) -> [String] {
        let cacheKey = generateCacheKey(content: content, settings: settings, viewSize: viewSize)
        
        // Check cache first
        if let cachedPages = paginationCache[cacheKey] {
            debugPrint("📄 PaginationService: Using cached pagination for \(cachedPages.count) pages")
            return cachedPages
        }
        
        // Calculate new pagination
        let pages = calculatePagination(content: content, settings: settings, viewSize: viewSize)
        
        // Cache the result
        paginationCache[cacheKey] = pages
        currentSettings = settings
        currentViewSize = viewSize
        
        debugPrint("📄 PaginationService: Paginated text into \(pages.count) pages")
        return pages
    }
    
    /// Check if the cache is valid for the given parameters
    /// - Parameters:
    ///   - settings: User settings to check against
    ///   - viewSize: View dimensions to check against
    /// - Returns: True if cache is valid, false otherwise
    func isCacheValid(for settings: UserSettings, viewSize: CGSize) -> Bool {
        guard let currentSettings = currentSettings,
              let currentViewSize = currentViewSize else {
            return false
        }
        
        return currentSettings.fontSize == settings.fontSize &&
               currentSettings.fontName == settings.fontName &&
               currentSettings.lineSpacing == settings.lineSpacing &&
               currentViewSize == viewSize
    }
    
    // MARK: - Private Methods
    
    /// Generate a cache key for the given parameters
    private func generateCacheKey(content: String, settings: UserSettings, viewSize: CGSize) -> String {
        let contentHash = content.hashValue
        return "\(contentHash)_\(settings.fontSize)_\(settings.fontName)_\(settings.lineSpacing)_\(viewSize.width)_\(viewSize.height)"
    }
    
    /// Calculate pagination for the given content and settings
    /// This is a simplified implementation - in a real app, this would use
    /// text measurement and layout calculations
    private func calculatePagination(content: String, settings: UserSettings, viewSize: CGSize) -> [String] {
        // Simple character-based pagination for now
        // In a real implementation, this would calculate based on:
        // - Font metrics
        // - Line height
        // - Available text area
        // - Word wrapping
        
        // Estimate characters per page based on font size
        let baseCharsPerPage = 500
        let fontSizeMultiplier = settings.fontSize / 16.0  // 16 is base font size
        let lineSpacingMultiplier = 1.0 / settings.lineSpacing  // More spacing = less content
        
        let charsPerPage = Int(Double(baseCharsPerPage) / fontSizeMultiplier * lineSpacingMultiplier)
        
        var pages: [String] = []
        var currentIndex = content.startIndex
        
        while currentIndex < content.endIndex {
            let endIndex = content.index(currentIndex, offsetBy: charsPerPage, limitedBy: content.endIndex) ?? content.endIndex
            let pageContent = String(content[currentIndex..<endIndex])
            pages.append(pageContent)
            currentIndex = endIndex
        }
        
        return pages.isEmpty ? [""] : pages
    }
    
    // MARK: - Deinit
    
    deinit {
        debugPrint("♻️ PaginationService: Deinitializing")
    }
} 