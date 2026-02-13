//
//  BackgroundPaginationService.swift
//  ReadAloudApp
//
//  Created on 2025-01-12
//  PGN-9: Decoupled Background Pagination
//

import Foundation
import SwiftUI
import Combine

/// Notification posted after each pagination batch is saved to SQLite.
/// `userInfo` contains "bookHash" (String) and "pageCount" (Int).
/// Notification posted when user interacts with the reader (page flip).
extension Notification.Name {
    static let paginationBatchCompleted = Notification.Name("com.readAloud.paginationBatchCompleted")
    static let userInteractionOccurred = Notification.Name("com.readAloud.userInteraction")
}

/// Service that monitors and paginates books in the background
/// This runs independently of the UI and saves results to cache
class BackgroundPaginationService {

    // MARK: - Properties

    private let persistenceService: PersistenceService
    private let fileProcessor: FileProcessor
    private let paginationQueue: DispatchQueue
    private var isRunning = false
    private var currentTask: Task<Void, Never>?
    /// Incremented when settings change to signal in-progress pagination to stop
    private var generationID: Int = 0

    /// Time of last detected user interaction
    private var lastUserInteractionTime = Date.distantPast
    private var cancellables = Set<AnyCancellable>()

    /// Minimum idle time before resuming pagination (seconds)
    private let requiredIdleTime: TimeInterval = 2.0

    // Batch size for incremental pagination (restored for faster completion when idle)
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

        // Listen for user interaction to pause pagination
        NotificationCenter.default.publisher(for: .userInteractionOccurred)
            .sink { [weak self] _ in
                self?.lastUserInteractionTime = Date()
                debugPrint("⏸️ BackgroundPaginationService: User activity detected, pausing")
            }
            .store(in: &cancellables)

        debugPrint("🔄 BackgroundPaginationService: Initialized with adaptive pausing")
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring for unpaginated books
    func startMonitoring() {
        guard !isRunning else {
            debugPrint("⚠️ BackgroundPaginationService: Already running")
            return
        }

        isRunning = true
        debugPrint("▶️ BackgroundPaginationService: Starting monitoring with adaptive pausing")

        // Start background task with explicit low priority
        currentTask = Task(priority: .utility) {
            // On startup, remove any stale caches that don't match current settings/view size
            await cleanupStaleCaches()
            await monitorLoop()
        }
    }

    /// Check if we should pause for user activity
    private func shouldPauseForUserActivity() -> Bool {
        let timeSinceInteraction = Date().timeIntervalSince(lastUserInteractionTime)
        return timeSinceInteraction < requiredIdleTime
    }
    
    /// Signal that settings or view size changed, cancelling any in-progress pagination.
    /// The monitor loop will pick up the new settings on its next cycle.
    func invalidateCurrentPagination() {
        generationID += 1
        debugPrint("🔄 BackgroundPaginationService: Pagination invalidated (gen \(generationID))")
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

            // Adaptive delay: short checks during activity, long when idle
            let delay = shouldPauseForUserActivity()
                ? 1.0  // Short check interval during activity
                : monitorInterval  // Normal 5s interval when idle

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
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
            let startGen = generationID

            // Process in batches; stop if generationID changes (settings invalidation)
            while currentIndex < content.count && isRunning && generationID == startGen {
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

                // Notify observers that new pages are available
                NotificationCenter.default.post(
                    name: .paginationBatchCompleted,
                    object: nil,
                    userInfo: ["bookHash": book.contentHash, "pageCount": pages.count]
                )

                // Adaptive delay: only delay when user is idle
                // Skip delay during user activity to let monitor loop check and pause
                if !shouldPauseForUserActivity() {
                    // Short delay when idle for cooperative scheduling
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
                // If user is active, skip delay and exit batch loop for immediate pause check
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
        
        // Create attributed string for pagination using shared utility
        let attributedString = TextStyling.createAttributedString(from: content, settings: settings)
        
        for batchPageOffset in 0..<batchSize {
            // Check for user activity before each page calculation
            if shouldPauseForUserActivity() {
                debugPrint("⏸️ BackgroundPaginationService: Pausing mid-batch due to user activity")
                break  // Exit batch early, will retry in next monitor cycle
            }

            guard currentIndex < content.count else { break }

            // Calculate page range using Core Text from current position
            let range = await paginationService.calculatePageRange(
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
