//
//  PaginationService.swift
//  ReadAloudApp
//
//  Created on 2024
//  Updated for PGN-1: Create PaginationService and LayoutCache Skeletons
//

import Foundation
import SwiftUI
import CoreText

/// PaginationService handles text layout and pagination calculations
/// This service is responsible for calculating page breaks based on text content,
/// font settings, and view dimensions
class PaginationService {
    
    // MARK: - Properties
    
    /// The text source to be paginated
    private let textSource: TextSource
    
    /// User settings affecting layout
    private let userSettings: UserSettings
    
    /// Layout cache for performance optimization
    private let layoutCache: LayoutCache
    
    /// Cache for paginated content to avoid recalculation
    private var paginationCache: [String: [String]] = [:]
    
    /// Current view dimensions
    private var currentViewSize: CGSize?
    
    // MARK: - Initialization
    
    /// Initialize PaginationService with TextSource and UserSettings
    /// - Parameters:
    ///   - textSource: The TextSource object containing the text to be paginated
    ///   - userSettings: The UserSettings object containing layout preferences
    init(textSource: TextSource, userSettings: UserSettings) {
        self.textSource = textSource
        self.userSettings = userSettings
        self.layoutCache = LayoutCache()
        debugPrint("📄 PaginationService: Initializing with TextSource and UserSettings")
    }
    
    // MARK: - Public API Methods
    
    /// Get the character range for a specific page
    /// - Parameter pageNumber: The page number (1-based)
    /// - Returns: NSRange representing the character range for the specified page
    func pageRange(for pageNumber: Int) -> NSRange {
        debugPrint("📄 PaginationService: pageRange(for:) called with page \(pageNumber)")
        
        // For now, return placeholder until we have view bounds
        // TODO: In a real implementation, this would need view bounds from the caller
        // or store the current view bounds in the service
        let estimatedCharsPerPage = 500
        let startLocation = (pageNumber - 1) * estimatedCharsPerPage
        let length = estimatedCharsPerPage
        
        return NSRange(location: startLocation, length: length)
    }
    
    /// Get the character range for a specific page with view bounds
    /// - Parameters:
    ///   - pageNumber: The page number (1-based)
    ///   - bounds: View bounds for text layout
    /// - Returns: NSRange representing the character range for the specified page
    func pageRange(for pageNumber: Int, bounds: CGRect) async -> NSRange {
        debugPrint("📄 PaginationService: pageRange(for:bounds:) called with page \(pageNumber), bounds: \(bounds)")
        
        // Get the full text content
        guard let fullText = getFullTextContent() else {
            debugPrint("⚠️ PaginationService: Could not retrieve full text content")
            return NSRange(location: 0, length: 0)
        }
        
        // Create attributed string with user settings
        let attributedString = createAttributedString(from: fullText)
        
        // Check cache first
        let cacheKey = "\(pageNumber)_\(bounds.width)_\(bounds.height)_\(userSettings.fontSize)_\(userSettings.fontName)"
        if let cachedRange = layoutCache.retrieveLayout(key: cacheKey) {
            debugPrint("📄 PaginationService: Using cached range for page \(pageNumber)")
            return cachedRange
        }
        
        // Calculate the starting index for the requested page
        var startIndex = 0
        if pageNumber > 1 {
            // We need to calculate all previous pages to get the start index
            let previousRanges = await calculateMultiplePageRanges(startIndex: 0, pageCount: pageNumber - 1, bounds: bounds, attributedString: attributedString)
            startIndex = previousRanges.last?.location ?? 0
            startIndex += previousRanges.last?.length ?? 0
        }
        
        // Calculate the range for the requested page
        let pageRange = await calculatePageRangeAsync(startIndex: startIndex, bounds: bounds, attributedString: attributedString)
        
        // Cache the result
        layoutCache.storeLayout(key: cacheKey, range: pageRange)
        
        return pageRange
    }
    
    /// Get the total number of pages for the current text and settings
    /// - Returns: Total page count
    func totalPageCount() -> Int {
        debugPrint("📄 PaginationService: totalPageCount() called")
        
        // Return a placeholder count based on text length estimation
        let textLength = getTextLength()
        let estimatedCharsPerPage = 500
        let pageCount = max(1, (textLength + estimatedCharsPerPage - 1) / estimatedCharsPerPage)
        
        debugPrint("📄 PaginationService: Estimated total pages: \(pageCount)")
        return pageCount
    }
    
    /// Get the total number of pages for the current text and settings with view bounds
    /// - Parameter bounds: View bounds for text layout
    /// - Returns: Total page count
    func totalPageCount(bounds: CGRect) async -> Int {
        debugPrint("📄 PaginationService: totalPageCount(bounds:) called with bounds: \(bounds)")
        
        // Get the full text content
        guard let fullText = getFullTextContent() else {
            debugPrint("⚠️ PaginationService: Could not retrieve full text content")
            return 0
        }
        
        // Create attributed string with user settings
        let attributedString = createAttributedString(from: fullText)
        
        // Check cache first
        let cacheKey = "totalPages_\(bounds.width)_\(bounds.height)_\(userSettings.fontSize)_\(userSettings.fontName)"
        if let cachedCount = layoutCache.retrieveIntValue(key: cacheKey) {
            debugPrint("📄 PaginationService: Using cached total page count: \(cachedCount)")
            return cachedCount
        }
        
        // Calculate all pages to get the total count
        var pageCount = 0
        var currentIndex = 0
        
        while currentIndex < attributedString.length {
            let range = await calculatePageRangeAsync(startIndex: currentIndex, bounds: bounds, attributedString: attributedString)
            
            // Safety check to prevent infinite loops
            if range.length == 0 {
                debugPrint("⚠️ PaginationService: Zero-length range detected, breaking pagination")
                break
            }
            
            pageCount += 1
            currentIndex = range.location + range.length
        }
        
        let finalPageCount = max(1, pageCount)
        
        // Cache the result
        layoutCache.storeIntValue(key: cacheKey, value: finalPageCount)
        
        debugPrint("📄 PaginationService: Calculated total pages: \(finalPageCount)")
        return finalPageCount
    }
    
    /// Invalidate the pagination cache when settings or content change
    func invalidateCache() {
        debugPrint("🗑️ PaginationService: Invalidating pagination cache")
        paginationCache.removeAll()
        layoutCache.clearCache()
        currentViewSize = nil
    }
    
    // MARK: - Legacy Methods (kept for compatibility)
    
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
        guard let currentViewSize = currentViewSize else {
            return false
        }
        
        return userSettings.fontSize == settings.fontSize &&
               userSettings.fontName == settings.fontName &&
               userSettings.lineSpacing == settings.lineSpacing &&
               currentViewSize == viewSize
    }
    
    // MARK: - Private Core Text Implementation (PGN-2)
    
    /// Calculate the character range that fits within the given bounds using Core Text
    /// - Parameters:
    ///   - startIndex: Starting character index in the attributed string
    ///   - bounds: View bounds (CGRect) available for text layout
    ///   - attributedString: The attributed string to layout
    /// - Returns: NSRange representing the characters that fit within the bounds
    /// - Note: This method is designed to run on a background thread to prevent UI freezes
    private func calculatePageRange(startIndex: Int, bounds: CGRect, attributedString: NSAttributedString) -> NSRange {
        debugPrint("📄 PaginationService: calculatePageRange(startIndex: \(startIndex), bounds: \(bounds))")
        
        // Ensure we have valid bounds
        guard bounds.width > 0, bounds.height > 0 else {
            debugPrint("⚠️ PaginationService: Invalid bounds provided")
            return NSRange(location: startIndex, length: 0)
        }
        
        // Ensure startIndex is within bounds
        guard startIndex >= 0, startIndex < attributedString.length else {
            debugPrint("⚠️ PaginationService: startIndex \(startIndex) out of bounds for string length \(attributedString.length)")
            return NSRange(location: startIndex, length: 0)
        }
        
        // Create a substring from the startIndex to the end
        let remainingRange = NSRange(location: startIndex, length: attributedString.length - startIndex)
        let remainingString = attributedString.attributedSubstring(from: remainingRange)
        
        // Create the framesetter from the attributed string
        let framesetter = CTFramesetterCreateWithAttributedString(remainingString)
        
        // Create a path that represents the text area (rectangle)
        let path = CGPath(rect: bounds, transform: nil)
        
        // Create a frame within the path to determine how much text fits
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        
        // Get the range of text that was actually laid out in the frame
        let frameRange = CTFrameGetStringRange(frame)
        
        // Convert CFRange to NSRange and adjust for the start index
        let fittingLength = frameRange.length
        let resultRange = NSRange(location: startIndex, length: fittingLength)
        
        debugPrint("📄 PaginationService: Calculated range: location=\(resultRange.location), length=\(resultRange.length)")
        
        return resultRange
    }
    
    /// Async version of calculatePageRange that runs on a background thread
    /// - Parameters:
    ///   - startIndex: Starting character index in the attributed string
    ///   - bounds: View bounds (CGRect) available for text layout
    ///   - attributedString: The attributed string to layout
    /// - Returns: NSRange representing the characters that fit within the bounds
    /// - Note: This method runs on a background thread to prevent UI freezes
    private func calculatePageRangeAsync(startIndex: Int, bounds: CGRect, attributedString: NSAttributedString) async -> NSRange {
        debugPrint("📄 PaginationService: calculatePageRangeAsync(startIndex: \(startIndex)) - dispatching to background thread")
        
        return await withCheckedContinuation { continuation in
            // Dispatch Core Text calculations to a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.calculatePageRange(startIndex: startIndex, bounds: bounds, attributedString: attributedString)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Calculate page ranges for multiple pages starting from a given index
    /// - Parameters:
    ///   - startIndex: Starting character index
    ///   - pageCount: Number of pages to calculate
    ///   - bounds: View bounds for text layout
    ///   - attributedString: The attributed string to layout
    /// - Returns: Array of NSRange objects for each page
    private func calculateMultiplePageRanges(startIndex: Int, pageCount: Int, bounds: CGRect, attributedString: NSAttributedString) async -> [NSRange] {
        debugPrint("📄 PaginationService: calculateMultiplePageRanges(startIndex: \(startIndex), pageCount: \(pageCount))")
        
        var ranges: [NSRange] = []
        var currentIndex = startIndex
        
        for pageNumber in 0..<pageCount {
            guard currentIndex < attributedString.length else {
                debugPrint("📄 PaginationService: Reached end of text at page \(pageNumber)")
                break
            }
            
            let range = await calculatePageRangeAsync(startIndex: currentIndex, bounds: bounds, attributedString: attributedString)
            ranges.append(range)
            
            // Move to the next page start position
            currentIndex = range.location + range.length
            
            // Safety check to prevent infinite loops
            if range.length == 0 {
                debugPrint("⚠️ PaginationService: Zero-length range detected, breaking to prevent infinite loop")
                break
            }
        }
        
        debugPrint("📄 PaginationService: Calculated \(ranges.count) page ranges")
        return ranges
    }
    
    // MARK: - Helper Methods
    
    /// Create an attributed string from text content with current user settings
    /// - Parameter content: The text content to convert
    /// - Returns: NSAttributedString with applied font and spacing settings
    private func createAttributedString(from content: String) -> NSAttributedString {
        let font = UIFont(name: userSettings.fontName, size: userSettings.fontSize) ?? UIFont.systemFont(ofSize: userSettings.fontSize)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = userSettings.lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        return NSAttributedString(string: content, attributes: attributes)
    }
    
    /// Get the full text content from the TextSource
    /// - Returns: Full text content as String, or nil if unable to retrieve
    private func getFullTextContent() -> String? {
        debugPrint("📄 PaginationService: getFullTextContent() called")
        
        switch textSource {
        case .memoryMapped(let nsData):
            // Convert NSData to String
            guard let string = String(data: nsData as Data, encoding: .utf8) else {
                debugPrint("⚠️ PaginationService: Failed to decode memory-mapped data as UTF-8")
                return nil
            }
            debugPrint("📄 PaginationService: Retrieved \(string.count) characters from memory-mapped source")
            return string
            
        case .streaming(let fileHandle):
            // Read all data from the file handle
            do {
                let data = fileHandle.readDataToEndOfFile()
                guard let string = String(data: data, encoding: .utf8) else {
                    debugPrint("⚠️ PaginationService: Failed to decode streaming data as UTF-8")
                    return nil
                }
                debugPrint("📄 PaginationService: Retrieved \(string.count) characters from streaming source")
                return string
            } catch {
                debugPrint("⚠️ PaginationService: Error reading from streaming source: \(error)")
                return nil
            }
        }
    }
    
    // MARK: - Existing Private Methods
    
    /// Get the text length from the TextSource
    /// - Returns: Estimated text length in characters
    private func getTextLength() -> Int {
        // TODO: Implement proper text length calculation based on TextSource type
        // This is a placeholder implementation for PGN-1
        switch textSource {
        case .memoryMapped(let nsData):
            return nsData.length
        case .streaming(_):
            // For streaming, we'll need to read chunks to estimate length
            // For now, return a placeholder
            return 10000
        }
    }
    
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