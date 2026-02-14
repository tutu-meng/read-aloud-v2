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
import UIKit

/// PaginationService handles text pagination using Core Text for precise layout calculations
/// This service takes text content and user settings to determine page breaks based on
/// font settings, and view dimensions
class PaginationService {
    
    // MARK: - Properties
    
    /// The pre-extracted text content to be paginated (encoding-aware)
    private let textContent: String
    
    /// User settings affecting layout
    private let userSettings: UserSettings
    
    /// Layout cache for performance optimization (used by legacy paginateText/invalidateCache)
    private let layoutCache: LayoutCache

    /// Current view dimensions (used by legacy isCacheValid)
    private var currentViewSize: CGSize?
    
    // MARK: - Initialization
    
    /// Initialize PaginationService with pre-extracted text content and UserSettings
    /// - Parameters:
    ///   - textContent: The pre-extracted text content (with correct encoding applied)
    ///   - userSettings: The UserSettings object containing layout preferences
    init(textContent: String, userSettings: UserSettings) {
        self.textContent = textContent
        self.userSettings = userSettings
        self.layoutCache = LayoutCache()
        debugPrint("📄 PaginationService: Initializing with pre-extracted text content (\(textContent.count) chars) and UserSettings")
    }
    
    /// Legacy initializer for backward compatibility with TextSource
    /// - Parameters:
    ///   - textSource: The TextSource object containing the text to be paginated
    ///   - userSettings: The UserSettings object containing layout preferences
    /// - Note: This initializer extracts text using UTF-8 and should be avoided for encoding-sensitive content
    convenience init(textSource: TextSource, userSettings: UserSettings) {
        let extractedText: String
        switch textSource {
        case .memoryMapped(let nsData):
            extractedText = String(data: nsData as Data, encoding: .utf8) ?? ""
        case .streaming(let fileHandle):
            let data = fileHandle.readDataToEndOfFile()
            extractedText = String(data: data, encoding: .utf8) ?? ""
        }
        self.init(textContent: extractedText, userSettings: userSettings)
        debugPrint("⚠️ PaginationService: Using legacy TextSource initializer with UTF-8 encoding")
    }
    
    // MARK: - Public API Methods

    /// Invalidate the pagination cache when settings or content change (legacy, used by tests)
    func invalidateCache() {
        debugPrint("🗑️ PaginationService: Invalidating pagination cache")
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
    
    /// Calculate the character range using standalone TextKit (background-thread safe).
    /// Uses NSTextStorage/NSLayoutManager/NSTextContainer — same engine as UITextView
    /// but without requiring MainActor. This ensures layout parity with display.
    func calculatePageRange(from startIndex: Int, in bounds: CGRect, with attributedString: NSAttributedString) async -> NSRange {
        guard bounds.width > 0, bounds.height > 0 else {
            return NSRange(location: startIndex, length: 0)
        }
        guard startIndex >= 0, startIndex < attributedString.length else {
            return NSRange(location: startIndex, length: 0)
        }

        let subRange = NSRange(location: startIndex, length: attributedString.length - startIndex)
        let subAttr = attributedString.attributedSubstring(from: subRange)

        // Standalone TextKit stack — same engine as UITextView, runs on any thread
        let storage = NSTextStorage(attributedString: subAttr)
        let layoutManager = NSLayoutManager()
        layoutManager.usesFontLeading = true
        layoutManager.allowsNonContiguousLayout = false

        // Reduce height by small buffer so UITextView (with its subtle internal
        // layout differences) never clips the last line
        let adjustedSize = CGSize(width: bounds.size.width, height: bounds.size.height - 2)
        let textContainer = NSTextContainer(size: adjustedSize)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byCharWrapping

        layoutManager.addTextContainer(textContainer)
        storage.addLayoutManager(layoutManager)

        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        return NSRange(location: startIndex + charRange.location, length: charRange.length)
    }
    
    /// Calculate the full layout for the entire document (PGN-3)
    /// This method iteratively calls the Core Text logic to generate a complete array of NSRange objects
    /// - Parameters:
    ///   - bounds: View bounds for text layout
    ///   - attributedString: The attributed string to layout
    /// - Returns: Array of NSRange objects representing all pages in the document
    /// - Note: This method is designed to run on a background thread for performance
    private func calculateFullLayout(bounds: CGRect, attributedString: NSAttributedString) async -> [NSRange] {
        debugPrint("📄 PaginationService: calculateFullLayout(bounds: \(bounds)) - starting full document layout")

        var pageRanges: [NSRange] = []
        var currentIndex = 0
        var pageNumber = 1

        // Iterate through the entire document, calculating each page
        while currentIndex < attributedString.length {
            let pageRange = await calculatePageRange(from: currentIndex, in: bounds, with: attributedString)
            
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
    
    /// Async wrapper for calculateFullLayout (PGN-3)
    private func calculateFullLayoutAsync(bounds: CGRect, attributedString: NSAttributedString) async -> [NSRange] {
        debugPrint("📄 PaginationService: calculateFullLayoutAsync(bounds: \(bounds))")
        return await calculateFullLayout(bounds: bounds, attributedString: attributedString)
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
        
        // Create attributed string with user settings using shared utility
        let attributedString = TextStyling.createAttributedString(from: fullText, settings: userSettings)

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
    
    /// Get the full text content from the pre-extracted text
    /// - Returns: Full text content as String
    private func getFullTextContent() -> String? {
        debugPrint("📄 PaginationService: getFullTextContent() returning pre-extracted content (\(textContent.count) chars)")
        return textContent
    }
    
    // MARK: - Deinit
    
    deinit {
        debugPrint("♻️ PaginationService: Deinitializing")
    }
} 
