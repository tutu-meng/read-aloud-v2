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
        
        // Validate page number
        guard pageNumber > 0 else {
            debugPrint("⚠️ PaginationService: Invalid page number: \(pageNumber)")
            return NSRange(location: 0, length: 0)
        }
        
        // Get the full layout (cached or calculated)
        let pageRanges = await getOrCalculateFullLayout(bounds: bounds)
        
        // Check if the requested page exists
        let pageIndex = pageNumber - 1  // Convert to 0-based index
        guard pageIndex < pageRanges.count else {
            debugPrint("⚠️ PaginationService: Page \(pageNumber) out of range (total pages: \(pageRanges.count))")
            return NSRange(location: 0, length: 0)
        }
        
        let range = pageRanges[pageIndex]
        debugPrint("📄 PaginationService: Page \(pageNumber) range: location=\(range.location), length=\(range.length)")
        return range
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
        
        // Get the full layout (cached or calculated)
        let pageRanges = await getOrCalculateFullLayout(bounds: bounds)
        
        let totalPages = pageRanges.count
        debugPrint("📄 PaginationService: Total page count: \(totalPages)")
        return totalPages
    }
    
    /// Invalidate the pagination cache when settings or content change
    func invalidateCache() {
        debugPrint("🗑️ PaginationService: Invalidating pagination cache")
        paginationCache.removeAll()
        layoutCache.clearCache()
        currentViewSize = nil
    }
    
    // MARK: - Legacy Methods (kept for compatibility)
    
    /// Paginate text content based on current settings and view dimensions using Core Text (BUG-1 FIX)
    /// This method now uses precise Core Text layout calculations instead of character estimation
    /// - Parameters:
    ///   - content: The full text content to paginate
    ///   - settings: User settings affecting layout (font, size, spacing)
    ///   - viewSize: Available view dimensions for text
    /// - Returns: Array of paginated text chunks based on Core Text calculations
    /// - Note: This method is now async as it depends on asynchronous Core Text layout calculations
    func paginateText(content: String, settings: UserSettings, viewSize: CGSize) async -> [String] {
        debugPrint("📄 PaginationService: paginateText() called with Core Text calculations (BUG-1 FIX)")
        
        // Step a: Call getOrCalculateFullLayout to retrieve accurate array of NSRange objects
        let bounds = CGRect(origin: .zero, size: viewSize)
        let pageRanges = await getOrCalculateFullLayout(bounds: bounds)
        
        // Step b: Create empty [String] array to hold page content
        var pages: [String] = []
        
        // Step c: Iterate through the returned NSRange array and extract corresponding substrings
        for (pageIndex, range) in pageRanges.enumerated() {
            // Validate range bounds to prevent crashes
            let safeRange = NSRange(
                location: min(range.location, content.count),
                length: min(range.length, content.count - min(range.location, content.count))
            )
            
            // Extract substring for this page
            if safeRange.location < content.count && safeRange.length > 0 {
                let startIndex = content.index(content.startIndex, offsetBy: safeRange.location)
                let endIndex = content.index(startIndex, offsetBy: safeRange.length)
                let pageContent = String(content[startIndex..<endIndex])
                
                // Step d: Append each extracted substring to the [String] array
                pages.append(pageContent)
                
                debugPrint("📄 PaginationService: Page \(pageIndex + 1): \(pageContent.count) characters")
            } else {
                debugPrint("⚠️ PaginationService: Invalid range for page \(pageIndex + 1): \(safeRange)")
                pages.append("")
            }
        }
        
        // Ensure we have at least one page
        if pages.isEmpty {
            debugPrint("⚠️ PaginationService: No pages generated, adding empty page")
            pages.append("")
        }
        
        debugPrint("📄 PaginationService: Paginated text into \(pages.count) pages using Core Text calculations")
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
    
    // MARK: - PGN-5: Core calculatePageRange Function Implementation
    
    /// Calculate the character range that fits within the given bounds using Core Text (PGN-5)
    /// This is the single, most critical function within the PaginationService that uses Apple's Core Text
    /// framework to perform precise measurement of how many characters can fit into a specific view area.
    /// - Parameters:
    ///   - startIndex: Starting character index in the full attributed string to measure from
    ///   - bounds: Exact bounds of the view where the text will be rendered
    ///   - attributedString: The full NSAttributedString of the book, containing all user-defined styles
    /// - Returns: NSRange representing the exact characters that fit perfectly on the page
    /// - Note: This function performs Core Text calculations on the current thread
    private func calculatePageRange(from startIndex: Int, in bounds: CGRect, with attributedString: NSAttributedString) -> NSRange {
        debugPrint("📄 PaginationService: calculatePageRange(from: \(startIndex), in: \(bounds))")
        debugPrint("📄 BOUNDS DEBUG: width=\(bounds.width), height=\(bounds.height), area=\(bounds.width * bounds.height)")
        
        // BOUNDS VALIDATION AND CORRECTION
        var correctedBounds = bounds
        // Validate input parameters
        guard correctedBounds.width > 0, correctedBounds.height > 0 else {
            debugPrint("⚠️ PaginationService: Invalid bounds provided")
            return NSRange(location: startIndex, length: 0)
        }
        
        guard startIndex >= 0, startIndex < attributedString.length else {
            debugPrint("⚠️ PaginationService: startIndex \(startIndex) out of bounds for string length \(attributedString.length)")
            return NSRange(location: startIndex, length: 0)
        }
        
        // Step 1: Create CTFramesetter from the full attributed string (PGN-5 requirement)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Step 2: Create CGPath from the corrected CGRect to define the shape of the text container (PGN-5 requirement)
        let path = CGPath(rect: correctedBounds, transform: nil)
        
        // Step 3: Call CTFramesetterCreateFrame to generate a CTFrame (PGN-5 requirement)
        // Use the startIndex to specify where to begin the layout
        let frameRange = CFRange(location: startIndex, length: attributedString.length - startIndex)
        let frame = CTFramesetterCreateFrame(framesetter, frameRange, path, nil)
        
        // Step 4: Call CTFrameGetStringRange on the resulting CTFrame to get the visible character range (PGN-5 requirement)
        let visibleRange = CTFrameGetVisibleStringRange(frame)
                // Pagination success check
        if visibleRange.length > 0 && visibleRange.length < attributedString.length - startIndex {
            debugPrint("✅ PAGINATION SUCCESS: \(visibleRange.length) characters fit on page (out of \(attributedString.length - startIndex) remaining)")
        }
      
        // Step 5: Return exact NSRange representing the characters that fit perfectly on the page (PGN-5 requirement)
        let resultRange = NSRange(location: visibleRange.location, length: visibleRange.length)
        
        debugPrint("📄 PaginationService: Calculated range: location=\(resultRange.location), length=\(resultRange.length)")
        
        return resultRange
    }
    
    /// Calculate the full layout for the entire document (PGN-3)
    /// This method iteratively calls the Core Text logic to generate a complete array of NSRange objects
    /// - Parameters:
    ///   - bounds: View bounds for text layout
    ///   - attributedString: The attributed string to layout
    /// - Returns: Array of NSRange objects representing all pages in the document
    /// - Note: This method is designed to run on a background thread for performance
    private func calculateFullLayout(bounds: CGRect, attributedString: NSAttributedString) -> [NSRange] {
        debugPrint("📄 PaginationService: calculateFullLayout(bounds: \(bounds)) - starting full document layout")
        
        var pageRanges: [NSRange] = []
        var currentIndex = 0
        var pageNumber = 1
        
        // Iterate through the entire document, calculating each page
        while currentIndex < attributedString.length {
            let pageRange = calculatePageRange(from: currentIndex, in: bounds, with: attributedString)
            
            // Safety check to prevent infinite loops
            if pageRange.length == 0 {
                debugPrint("⚠️ PaginationService: Zero-length range detected at page \(pageNumber), breaking pagination")
                break
            }
            
            pageRanges.append(pageRange)
            currentIndex = pageRange.location + pageRange.length
            
            debugPrint("📄 PaginationService: Calculated page \(pageNumber): range=\(pageRange.location)-\(pageRange.location + pageRange.length)")
            pageNumber += 1
            
            // Safety check to prevent runaway pagination
            if pageNumber > 10000 {
                debugPrint("⚠️ PaginationService: Reached maximum page limit (10000), breaking pagination")
                break
            }
        }
        
        debugPrint("📄 PaginationService: Full layout calculation complete - \(pageRanges.count) pages")
        return pageRanges
    }
    
    /// Async version of calculateFullLayout that runs on a background thread (PGN-3)
    /// - Parameters:
    ///   - bounds: View bounds for text layout
    ///   - attributedString: The attributed string to layout
    /// - Returns: Array of NSRange objects representing all pages in the document
    /// - Note: This method runs on a background thread to prevent UI freezes
    private func calculateFullLayoutAsync(bounds: CGRect, attributedString: NSAttributedString) async -> [NSRange] {
        debugPrint("📄 PaginationService: calculateFullLayoutAsync(bounds: \(bounds)) - dispatching to background thread")
        
        return await withCheckedContinuation { continuation in
            // Dispatch full layout calculation to a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.calculateFullLayout(bounds: bounds, attributedString: attributedString)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Get or calculate the full layout for the entire document with caching (PGN-3)
    /// This method checks the cache first, and if not found, performs the full layout calculation
    /// - Parameter bounds: View bounds for text layout
    /// - Returns: Array of NSRange objects representing all pages in the document
    /// - Note: This method runs on a background thread and caches the results
    private func getOrCalculateFullLayout(bounds: CGRect) async -> [NSRange] {
        debugPrint("📄 PaginationService: getOrCalculateFullLayout(bounds: \(bounds)) - checking cache")
        
        // Get the full text content
        guard let fullText = getFullTextContent() else {
            debugPrint("⚠️ PaginationService: Could not retrieve full text content")
            return []
        }
        
        // Generate cache key and content hash
        let contentHash = getContentHash()
        
        // Check if we have a cached layout using the LayoutCache's comprehensive storage
        if let cachedLayout = layoutCache.retrieveLayout(
            userSettings: userSettings,
            viewSize: CGSize(width: bounds.width, height: bounds.height),
            contentHash: contentHash
        ) {
            debugPrint("📄 PaginationService: Using cached full layout with \(cachedLayout.pageRanges.count) pages")
            return cachedLayout.pageRanges
        }
        
        // No cached layout found, calculate the full layout
        debugPrint("📄 PaginationService: No cached layout found, calculating full layout")
        
        // Create attributed string with user settings
        let my_pageview = PageView(content: fullText, pageIndex: 0)
        let attributedString = my_pageview.createAttributedString(from: fullText, settings: userSettings)
        
        // Calculate the full layout asynchronously
        let pageRanges = await calculateFullLayoutAsync(bounds: bounds, attributedString: attributedString)
        
        // Store the calculated layout in the cache
        layoutCache.storeLayout(
            userSettings: userSettings,
            viewSize: CGSize(width: bounds.width, height: bounds.height),
            contentHash: contentHash,
            pageCount: pageRanges.count,
            pageRanges: pageRanges
        )
        
        debugPrint("📄 PaginationService: Calculated and cached full layout with \(pageRanges.count) pages")
        return pageRanges
    }
    
    /// Async version of calculatePageRange that runs on a background thread (PGN-5 PREFERRED IMPLEMENTATION)
    /// This is the preferred implementation that explicitly dispatches Core Text calculations to a background thread
    /// to prevent any blocking or stuttering of the main UI thread, as required by PGN-5.
    /// - Parameters:
    ///   - startIndex: Starting character index in the full attributed string to measure from
    ///   - bounds: Exact bounds of the view where the text will be rendered
    ///   - attributedString: The full NSAttributedString of the book, containing all user-defined styles
    /// - Returns: NSRange representing the exact characters that fit perfectly on the page
    /// - Note: All Core Text calculations are explicitly dispatched to DispatchQueue.global(qos: .userInitiated)
    private func calculatePageRangeAsync(from startIndex: Int, in bounds: CGRect, with attributedString: NSAttributedString) async -> NSRange {
        debugPrint("📄 PaginationService: calculatePageRangeAsync(from: \(startIndex), in: \(bounds)) - dispatching to background thread")
        
        return await withCheckedContinuation { continuation in
            // PGN-5 Requirement: All Core Text calculations must be explicitly dispatched to a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.calculatePageRange(from: startIndex, in: bounds, with: attributedString)
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
    private func calculateMultiplePageRanges(from startIndex: Int, pageCount: Int, in bounds: CGRect, with attributedString: NSAttributedString) async -> [NSRange] {
        debugPrint("📄 PaginationService: calculateMultiplePageRanges(startIndex: \(startIndex), pageCount: \(pageCount))")
        
        var ranges: [NSRange] = []
        var currentIndex = startIndex
        
        for pageNumber in 0..<pageCount {
            guard currentIndex < attributedString.length else {
                debugPrint("📄 PaginationService: Reached end of text at page \(pageNumber)")
                break
            }
            
            let range = await calculatePageRangeAsync(from: currentIndex, in: bounds, with: attributedString)
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
    
    /// Generate a unique cache key for full layout calculation (PGN-3)
    /// - Parameters:
    ///   - bounds: View bounds for text layout
    ///   - contentHash: Hash of the text content
    /// - Returns: Unique cache key string
    private func generateFullLayoutCacheKey(bounds: CGRect, contentHash: Int) -> String {
        // Create a hash of the relevant UserSettings properties
        let settingsHash = "\(userSettings.fontName)_\(userSettings.fontSize)_\(userSettings.lineSpacing)".hashValue
        
        // Combine all relevant parameters into a unique key
        let key = "fullLayout_\(bounds.width)_\(bounds.height)_\(settingsHash)_\(contentHash)"
        
        debugPrint("📄 PaginationService: Generated full layout cache key: \(key)")
        return key
    }
    
    /// Get the hash of the current text content for cache key generation
    /// - Returns: Hash value of the text content, or 0 if unable to retrieve
    private func getContentHash() -> Int {
        guard let content = getFullTextContent() else {
            debugPrint("⚠️ PaginationService: Could not retrieve content for hashing")
            return 0
        }
        
        let hash = content.hashValue
        debugPrint("📄 PaginationService: Generated content hash: \(hash)")
        return hash
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
    
    // MARK: - Deinit
    
    deinit {
        debugPrint("♻️ PaginationService: Deinitializing")
    }
} 
