//
//  BackgroundPaginationService.swift
//  ReadAloudApp
//
//  Created on 2025-01-12
//  PGN-9: Decoupled Background Pagination
//

import Foundation
import SwiftUI

/// Service that monitors and paginates books in the background
/// This runs independently of the UI and saves results to cache
class BackgroundPaginationService {
    
    // MARK: - Properties
    
    private let persistenceService: PersistenceService
    private let fileProcessor: FileProcessor
    private let paginationQueue: DispatchQueue
    private var isRunning = false
    private var currentTask: Task<Void, Never>?
    
    // Batch size for incremental pagination
    private let batchSize = 10
    
    // Monitor interval in seconds
    private let monitorInterval: TimeInterval = 5.0
    
    // MARK: - Initialization
    
    init(persistenceService: PersistenceService = .shared,
         fileProcessor: FileProcessor = FileProcessor()) {
        self.persistenceService = persistenceService
        self.fileProcessor = fileProcessor
        self.paginationQueue = DispatchQueue(
            label: "com.readAloud.pagination",
            qos: .background
        )
        debugPrint("🔄 BackgroundPaginationService: Initialized")
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring for unpaginated books
    func startMonitoring() {
        guard !isRunning else {
            debugPrint("⚠️ BackgroundPaginationService: Already running")
            return
        }
        
        isRunning = true
        debugPrint("▶️ BackgroundPaginationService: Starting monitoring")
        
        // Start background task
        currentTask = Task {
            // On startup, remove any stale caches that don't match current settings/view size
            await cleanupStaleCaches()
            await monitorLoop()
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        debugPrint("⏹️ BackgroundPaginationService: Stopping monitoring")
        isRunning = false
        currentTask?.cancel()
        currentTask = nil
    }
    
    // MARK: - Private Methods
    
    /// Main monitoring loop
    private func monitorLoop() async {
        while isRunning {
            await checkAndProcessNextBook()
            
            // Sleep for monitor interval
            try? await Task.sleep(nanoseconds: UInt64(monitorInterval * 1_000_000_000))
        }
    }
    
    /// Check for unpaginated books and process the next one
    private func checkAndProcessNextBook() async {
        debugPrint("🔍 BackgroundPaginationService: Checking for unpaginated books")
        
        do {
            // Get all books from library
            let books = try persistenceService.loadBookLibrary()
            
            // Get current user settings
            guard let settings = try? persistenceService.loadUserSettings() else {
                debugPrint("⚠️ BackgroundPaginationService: No user settings found")
                return
            }
            
            // Get current view size
            let viewSize = persistenceService.loadLastViewSize()
            
            // Find first book that needs pagination
            for book in books {
                let cacheKey = PaginationCache.cacheKey(
                    bookHash: book.contentHash,
                    settings: settings,
                    viewSize: viewSize
                )
                
                let cache = try? persistenceService.loadPaginationCache(
                    bookHash: book.contentHash,
                    settingsKey: cacheKey
                )
                // Remove any other cache files for this book to keep only the current key
                persistenceService.cleanupPaginationCaches(for: book.contentHash, keepSettingsKey: cacheKey)
                
                if cache == nil || !(cache?.isComplete ?? true) {
                    // Found a book that needs pagination
                    debugPrint("📖 BackgroundPaginationService: Found book to paginate: \(book.title)")
                    await processBook(book, settings: settings, viewSize: viewSize, existingCache: cache)
                    break // Process one book at a time
                }
            }
        } catch {
            debugPrint("❌ BackgroundPaginationService: Error checking books: \(error)")
        }
    }

    /// Remove non-current pagination caches for all books at startup
    private func cleanupStaleCaches() async {
        do {
            let books = try persistenceService.loadBookLibrary()
            guard let settings = try? persistenceService.loadUserSettings() else { return }
            let viewSize = persistenceService.loadLastViewSize()
            for book in books {
                let key = PaginationCache.cacheKey(bookHash: book.contentHash, settings: settings, viewSize: viewSize)
                persistenceService.cleanupPaginationCaches(for: book.contentHash, keepSettingsKey: key)
            }
        } catch {
            debugPrint("⚠️ BackgroundPaginationService: cleanupStaleCaches failed: \(error)")
        }
    }
    
    /// Process pagination for a specific book
    private func processBook(_ book: Book,
                           settings: UserSettings,
                           viewSize: CGSize,
                           existingCache: PaginationCache?) async {
        
        debugPrint("📄 BackgroundPaginationService: Processing book: \(book.title)")
        
        do {
            // Load book content using existing FileProcessor APIs
            let textSource = try await fileProcessor.loadText(from: book.fileURL)
            let content = try await fileProcessor.extractTextContent(
                from: textSource,
                using: book.stringEncoding,
                filename: book.title
            )
            
            // Create pagination service
            let paginationService = PaginationService(
                textContent: content,
                userSettings: settings
            )
            
            // Generate cache key
            let cacheKey = PaginationCache.cacheKey(
                bookHash: book.contentHash,
                settings: settings,
                viewSize: viewSize
            )
            
            // Start from existing progress or beginning
            var currentIndex = existingCache?.lastProcessedIndex ?? 0
            var pages = existingCache?.pages ?? []
            
            // Process in batches
            while currentIndex < content.count && isRunning {
                // Calculate next batch of pages
                let batchResult = await calculateBatch(
                    paginationService: paginationService,
                    content: content,
                    startIndex: currentIndex,
                    settings: settings,
                    viewSize: viewSize,
                    batchSize: batchSize,
                    processedPagesCount: pages.count
                )
                
                // Add new pages
                pages.append(contentsOf: batchResult.pages)
                currentIndex = batchResult.lastProcessedIndex
                
                // Save progress incrementally to SQLite
                try persistenceService.upsertPaginationBatch(
                    bookHash: book.contentHash,
                    settingsKey: cacheKey,
                    viewSize: viewSize,
                    pages: batchResult.pages,
                    lastProcessedIndex: currentIndex,
                    isComplete: currentIndex >= content.count,
                    totalPages: currentIndex >= content.count ? (pages.count) : nil
                )
                
                debugPrint("💾 BackgroundPaginationService: Saved \(pages.count) pages (progress: \(currentIndex)/\(content.count))")
                
                // Small delay to not hog resources
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            if currentIndex >= content.count {
                debugPrint("✅ BackgroundPaginationService: Completed pagination for \(book.title)")
            }
            
        } catch {
            debugPrint("❌ BackgroundPaginationService: Error processing book: \(error)")
        }
    }
    
    /// Calculate a batch of pages
    private func calculateBatch(paginationService: PaginationService,
                               content: String,
                               startIndex: Int,
                               settings: UserSettings,
                               viewSize: CGSize,
                                batchSize: Int,
                                processedPagesCount: Int) async -> (pages: [PaginationCache.PageRange], lastProcessedIndex: Int) {
        
        var pages: [PaginationCache.PageRange] = []
        var currentIndex = startIndex
        let bounds = CGRect(origin: .zero, size: viewSize)
        
        // Create attributed string for pagination
        let pageView = PageView(content: "", pageIndex: 0)
        let attributedString = pageView.createAttributedString(from: content, settings: settings)
        
        for batchPageOffset in 0..<batchSize {
            guard currentIndex < content.count else { break }
            
            // Calculate page range using Core Text from current position
            let range = paginationService.calculatePageRange(
                from: currentIndex,
                in: bounds,
                with: attributedString
            )
            
            // Validate range
            guard range.length > 0 else { 
                debugPrint("⚠️ BackgroundPaginationService: Zero-length range at index \(currentIndex)")
                break 
            }
            
            // Extract page content using NSString to respect UTF-16 indices from CoreText
            let nsContent = content as NSString
            let safeLen = min(range.length, max(0, nsContent.length - range.location))
            let pageContent = safeLen > 0 ? nsContent.substring(with: NSRange(location: range.location, length: safeLen)) : ""
            
            // Create page range with page number (1-based)
            let pageNumber = processedPagesCount + pages.count + 1
            let pageRange = PaginationCache.PageRange(
                pageNumber: pageNumber,
                content: pageContent,
                startIndex: range.location,
                endIndex: range.location + range.length
            )
            
            pages.append(pageRange)
            currentIndex = range.location + safeLen
        }
        
        return (pages, currentIndex)
    }
    
    // MARK: - Deinit
    
    deinit {
        stopMonitoring()
        debugPrint("♻️ BackgroundPaginationService: Deinitialized")
    }
}
