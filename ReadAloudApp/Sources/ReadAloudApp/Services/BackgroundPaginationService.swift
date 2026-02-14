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
    /// Posted when seed window pages are ready. userInfo: "bookHash" (String), "seedPages" ([[String: Any]])
    static let seedWindowReady = Notification.Name("com.readAloud.seedWindowReady")
    /// Posted when background pagination has caught up to the seed anchor. userInfo: "bookHash" (String), "realPageNumber" (Int, 0-based)
    static let seedReconciled = Notification.Name("com.readAloud.seedReconciled")
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

    /// Character index to prioritize for seed window calculation.
    /// Set by the ViewModel when opening a book with saved progress.
    private var priorityAnchorCharIndex: Int = 0
    private var priorityBookHash: String = ""
    
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

    /// Set a priority anchor so the next pagination run for this book calculates
    /// a seed window before starting the linear pass.
    func setPriorityAnchor(bookHash: String, characterIndex: Int) {
        priorityBookHash = bookHash
        priorityAnchorCharIndex = characterIndex
        debugPrint("📌 BackgroundPaginationService: Priority anchor set at char \(characterIndex) for \(bookHash)")
    }

    /// Calculate a small seed window of pages starting at `anchorCharIndex`.
    /// Returns an array of (content, range) tuples. Does NOT persist to SQLite.
    func calculateSeedWindow(
        for book: Book,
        anchorCharIndex: Int,
        settings: UserSettings,
        viewSize: CGSize,
        windowSize: Int = 3
    ) async -> [(content: String, range: NSRange)] {
        debugPrint("🌱 BackgroundPaginationService: Calculating seed window (\(windowSize) pages) from char \(anchorCharIndex)")
        do {
            let textSource = try await fileProcessor.loadText(from: book.fileURL)
            let content = try await fileProcessor.extractTextContent(
                from: textSource,
                using: book.stringEncoding,
                filename: book.title
            )

            guard anchorCharIndex < (content as NSString).length else { return [] }

            let paginationService = PaginationService(textContent: content, userSettings: settings)
            let attributedString = TextStyling.createAttributedString(from: content, settings: settings)
            let bounds = CGRect(origin: .zero, size: viewSize)
            let nsContent = content as NSString

            var results: [(content: String, range: NSRange)] = []
            var currentIndex = anchorCharIndex

            for _ in 0..<windowSize {
                guard currentIndex < nsContent.length else { break }
                let range = await paginationService.calculatePageRange(
                    from: currentIndex,
                    in: bounds,
                    with: attributedString
                )
                guard range.length > 0 else { break }
                let safeLen = min(range.length, max(0, nsContent.length - range.location))
                let pageContent = safeLen > 0 ? nsContent.substring(with: NSRange(location: range.location, length: safeLen)) : ""
                results.append((content: pageContent, range: NSRange(location: range.location, length: safeLen)))
                currentIndex = range.location + safeLen
            }

            debugPrint("🌱 BackgroundPaginationService: Seed window ready with \(results.count) pages")
            return results
        } catch {
            debugPrint("❌ BackgroundPaginationService: Seed window calculation failed: \(error)")
            return []
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
    
    /// Process pagination for a specific book.
    /// When a priority anchor is set and the cache is empty, uses two-phase pagination:
    ///   Phase 1: anchor → end-of-book (estimated page numbers, so user can read forward immediately)
    ///   Phase 2: 0 → anchor (correct page numbers, fills in backward)
    ///   Then renumbers Phase 1 pages to correct offsets.
    private func processBook(_ book: Book,
                           settings: UserSettings,
                           viewSize: CGSize,
                           existingCache: PaginationCache?) async {

        debugPrint("📄 BackgroundPaginationService: Processing book: \(book.title)")

        do {
            let textSource = try await fileProcessor.loadText(from: book.fileURL)
            let content = try await fileProcessor.extractTextContent(
                from: textSource,
                using: book.stringEncoding,
                filename: book.title
            )

            let paginationService = PaginationService(textContent: content, userSettings: settings)
            let cacheKey = PaginationCache.cacheKey(bookHash: book.contentHash, settings: settings, viewSize: viewSize)
            let startGen = generationID
            let attributedString = TextStyling.createAttributedString(from: content, settings: settings)

            // Decide whether to use two-phase (priority) or linear pagination
            let usePriorityPagination = priorityAnchorCharIndex > 0
                && priorityBookHash == book.contentHash
                && existingCache == nil
                && priorityAnchorCharIndex < content.count

            if usePriorityPagination {
                await processBookTwoPhase(
                    book: book, content: content, paginationService: paginationService,
                    cacheKey: cacheKey, settings: settings, viewSize: viewSize,
                    attributedString: attributedString, startGen: startGen
                )
            } else {
                await processBookLinear(
                    book: book, content: content, paginationService: paginationService,
                    cacheKey: cacheKey, settings: settings, viewSize: viewSize,
                    existingCache: existingCache, attributedString: attributedString, startGen: startGen
                )
            }
        } catch {
            debugPrint("❌ BackgroundPaginationService: Error processing book: \(error)")
        }
    }

    /// Original linear pagination: char 0 → end
    private func processBookLinear(
        book: Book, content: String, paginationService: PaginationService,
        cacheKey: String, settings: UserSettings, viewSize: CGSize,
        existingCache: PaginationCache?, attributedString: NSAttributedString, startGen: Int
    ) async {
        var currentIndex = existingCache?.lastProcessedIndex ?? 0
        var pageCount = existingCache?.pages.count ?? 0

        while currentIndex < content.count && isRunning && generationID == startGen {
            let batchResult = await calculateBatch(
                paginationService: paginationService, content: content,
                startIndex: currentIndex, settings: settings, viewSize: viewSize,
                batchSize: batchSize, processedPagesCount: pageCount, attributedString: attributedString
            )
            pageCount += batchResult.pages.count
            currentIndex = batchResult.lastProcessedIndex

            try? persistenceService.upsertPaginationBatch(
                bookHash: book.contentHash, settingsKey: cacheKey, viewSize: viewSize,
                pages: batchResult.pages, lastProcessedIndex: currentIndex,
                isComplete: currentIndex >= content.count,
                totalPages: currentIndex >= content.count ? pageCount : nil
            )
            debugPrint("💾 BackgroundPaginationService: Saved \(pageCount) pages (progress: \(currentIndex)/\(content.count))")
            notifyBatchCompleted(bookHash: book.contentHash, pageCount: pageCount)
            checkReconciliation(bookHash: book.contentHash, cacheKey: cacheKey, currentIndex: currentIndex)
            if !shouldPauseForUserActivity() {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        if currentIndex >= content.count {
            debugPrint("✅ BackgroundPaginationService: Completed pagination for \(book.title)")
        }
    }

    /// Two-phase pagination: anchor → end, then 0 → anchor, then renumber.
    private func processBookTwoPhase(
        book: Book, content: String, paginationService: PaginationService,
        cacheKey: String, settings: UserSettings, viewSize: CGSize,
        attributedString: NSAttributedString, startGen: Int
    ) async {
        let anchor = priorityAnchorCharIndex
        // Use a large temporary offset for Phase 1 page numbers to avoid collision
        // with Phase 2 pages (which use correct numbers 1..N). After Phase 2 completes,
        // we renumber Phase 1 pages to their correct positions.
        let tempOffset = 1_000_000

        debugPrint("📄 BackgroundPaginationService: Two-phase pagination — anchor at char \(anchor), tempOffset=\(tempOffset)")

        // ── Phase 1: anchor → end (pages numbered from tempOffset + 1) ──
        var fwdIndex = anchor
        var fwdPageCount = 0

        while fwdIndex < content.count && isRunning && generationID == startGen {
            let batchResult = await calculateBatch(
                paginationService: paginationService, content: content,
                startIndex: fwdIndex, settings: settings, viewSize: viewSize,
                batchSize: batchSize, processedPagesCount: tempOffset + fwdPageCount,
                attributedString: attributedString
            )
            fwdPageCount += batchResult.pages.count
            fwdIndex = batchResult.lastProcessedIndex

            try? persistenceService.upsertPaginationBatch(
                bookHash: book.contentHash, settingsKey: cacheKey, viewSize: viewSize,
                pages: batchResult.pages, lastProcessedIndex: fwdIndex,
                isComplete: false, totalPages: nil
            )
            debugPrint("💾 BackgroundPaginationService: Phase 1 — \(fwdPageCount) pages from anchor (progress: \(fwdIndex)/\(content.count))")
            notifyBatchCompleted(bookHash: book.contentHash, pageCount: tempOffset + fwdPageCount)
            if !shouldPauseForUserActivity() {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        guard isRunning && generationID == startGen else { return }

        // ── Phase 2: 0 → anchor (pages numbered from 1, correct numbers) ──
        var bwdIndex = 0
        var bwdPageCount = 0

        debugPrint("📄 BackgroundPaginationService: Phase 2 — filling pages 0..\(anchor)")
        while bwdIndex < anchor && isRunning && generationID == startGen {
            let batchResult = await calculateBatch(
                paginationService: paginationService, content: content,
                startIndex: bwdIndex, settings: settings, viewSize: viewSize,
                batchSize: batchSize, processedPagesCount: bwdPageCount,
                attributedString: attributedString
            )
            bwdPageCount += batchResult.pages.count
            bwdIndex = batchResult.lastProcessedIndex

            try? persistenceService.upsertPaginationBatch(
                bookHash: book.contentHash, settingsKey: cacheKey, viewSize: viewSize,
                pages: batchResult.pages, lastProcessedIndex: bwdIndex,
                isComplete: false, totalPages: nil
            )
            debugPrint("💾 BackgroundPaginationService: Phase 2 — \(bwdPageCount) backward pages (progress: \(bwdIndex)/\(anchor))")
            notifyBatchCompleted(bookHash: book.contentHash, pageCount: bwdPageCount + fwdPageCount)
            if !shouldPauseForUserActivity() {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        guard isRunning && generationID == startGen else { return }

        // ── Renumber Phase 1 pages from tempOffset+1.. to bwdPageCount+1.. ──
        let delta = bwdPageCount - tempOffset
        debugPrint("🔢 BackgroundPaginationService: Renumbering Phase 1 pages by delta \(delta) (tempOffset=\(tempOffset), actualPagesBefore=\(bwdPageCount))")
        try? persistenceService.renumberPages(
            bookHash: book.contentHash, settingsKey: cacheKey,
            fromPageNumber: tempOffset + 1, delta: delta
        )
        let totalPages = bwdPageCount + fwdPageCount

        // Mark complete
        try? persistenceService.upsertPaginationBatch(
            bookHash: book.contentHash, settingsKey: cacheKey, viewSize: viewSize,
            pages: [], lastProcessedIndex: content.count,
            isComplete: true, totalPages: totalPages
        )
        notifyBatchCompleted(bookHash: book.contentHash, pageCount: totalPages)

        // Post reconciliation with the real page number
        if let realPage = try? persistenceService.loadPageContaining(
            bookHash: book.contentHash, settingsKey: cacheKey, characterIndex: anchor
        ) {
            debugPrint("🎯 BackgroundPaginationService: Reconciled anchor → page \(realPage)")
            NotificationCenter.default.post(
                name: .seedReconciled, object: nil,
                userInfo: ["bookHash": book.contentHash, "realPageNumber": realPage - 1]
            )
        }
        priorityAnchorCharIndex = 0
        priorityBookHash = ""

        debugPrint("✅ BackgroundPaginationService: Completed two-phase pagination for \(book.title)")
    }

    private func notifyBatchCompleted(bookHash: String, pageCount: Int) {
        NotificationCenter.default.post(
            name: .paginationBatchCompleted, object: nil,
            userInfo: ["bookHash": bookHash, "pageCount": pageCount]
        )
    }

    private func checkReconciliation(bookHash: String, cacheKey: String, currentIndex: Int) {
        guard priorityAnchorCharIndex > 0 && priorityBookHash == bookHash
              && currentIndex >= priorityAnchorCharIndex else { return }
        if let realPage = try? persistenceService.loadPageContaining(
            bookHash: bookHash, settingsKey: cacheKey, characterIndex: priorityAnchorCharIndex
        ) {
            debugPrint("🎯 BackgroundPaginationService: Reconciled anchor at char \(priorityAnchorCharIndex) → page \(realPage)")
            NotificationCenter.default.post(
                name: .seedReconciled, object: nil,
                userInfo: ["bookHash": bookHash, "realPageNumber": realPage - 1]
            )
            priorityAnchorCharIndex = 0
            priorityBookHash = ""
        }
    }

    private func estimateTotalPages(fileSize: Int, isMultiByte: Bool) -> Int {
        let bytesPerChar: Double = isMultiByte ? 2.0 : 1.0
        let charsPerPage: Double = isMultiByte ? 500 : 800
        return max(10, Int(Double(fileSize) / bytesPerChar / charsPerPage))
    }
    
    /// Calculate a batch of pages
    private func calculateBatch(paginationService: PaginationService,
                               content: String,
                               startIndex: Int,
                               settings: UserSettings,
                               viewSize: CGSize,
                                batchSize: Int,
                                processedPagesCount: Int,
                                attributedString: NSAttributedString) async -> (pages: [PaginationCache.PageRange], lastProcessedIndex: Int) {

        var pages: [PaginationCache.PageRange] = []
        var currentIndex = startIndex
        let bounds = CGRect(origin: .zero, size: viewSize)
        
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
