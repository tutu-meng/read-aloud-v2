//
//  ReaderViewModel.swift
//  ReadAloudApp
//
//  Created on 2024
//  Updated for PGN-9: Simplified to read from pagination cache only
//

import SwiftUI
import Combine
import AVFoundation

/// ReaderViewModel manages the state and logic for the reader view
/// PGN-9: Simplified to only read from pagination cache
class ReaderViewModel: ObservableObject {
    // MARK: - Properties
    @Published var currentPage = 0 {
        didSet {
            if currentPage != oldValue && !isLoading {
                updatePageContent()
                saveCurrentProgress()
            }
        }
    }
    @Published var totalPages = 0
    @Published var pageContent = ""
    @Published var isLoading = true
    @Published var isSpeaking = false
    @Published var isPaginationComplete = false
    @Published var paginationProgress: Double = 0.0
    @Published var shouldPresentTTSPicker = false
    
    /// The book being read
    var book: Book
    let coordinator: AppCoordinator
    private let persistenceService: PersistenceService
    private var cancellables = Set<AnyCancellable>()
    /// LRU page cache: page index (0-based) -> content string
    private var pageCache: [Int: String] = [:]
    private let pageCacheCapacity = 20
    private var pageCacheOrder: [Int] = []  // tracks access order for LRU eviction
    private var cachedPageCount: Int = 0
    private var currentCacheKey: String = ""
    private var currentViewSize: CGSize = .zero
    private var currentContentSize: CGSize = .zero
    private var currentReadingProgress: ReadingProgress?
    private let speech: SpeechSynthesizing = SystemSpeechService()
    
    // MARK: - Initialization
    init(book: Book, coordinator: AppCoordinator) {
        self.book = book
        self.coordinator = coordinator
        self.persistenceService = PersistenceService.shared
        
        setupSettingsObservation()
        setupAppLifecycleObservation()
        loadBook()
    }
    
    // MARK: - Settings Observation
    
    /// Set up observation for UserSettings changes
    private func setupSettingsObservation() {
        // Simple observation that triggers on any settings change
        coordinator.$userSettings
            .dropFirst() // Skip initial value
            .sink { [weak self] newSettings in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)
    }
    
    /// Set up observation for app lifecycle events
    private func setupAppLifecycleObservation() {
        // Save progress when app enters background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.saveCurrentProgress()
            }
            .store(in: &cancellables)
        
        // Save progress when app will terminate
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.saveCurrentProgress()
            }
            .store(in: &cancellables)
    }
    
    /// Handle settings changes that affect layout
    private func handleSettingsChange() {
        debugPrint("📱 ReaderViewModel: Settings changed, will reload from new cache")
        
        // Clear cached state
        clearPageCache()
        currentCacheKey = ""
        cachedPageCount = 0
        isPaginationComplete = false
        
        // Reload from cache with new settings
        loadBook()
    }
    
    // MARK: - Methods
    
    /// Load book from pagination cache
    func loadBook() {
        isLoading = true

        // Load saved reading progress first
        loadSavedProgress()

        // Load from cache and listen for background pagination updates
        Task {
            await loadFromCache()

            // Observe background pagination batch notifications instead of polling
            await MainActor.run {
                self.setupPaginationObservation()
            }
        }
    }

    /// Observe notifications from BackgroundPaginationService
    private func setupPaginationObservation() {
        NotificationCenter.default.publisher(for: .paginationBatchCompleted)
            .sink { [weak self] notification in
                guard let self = self else { return }
                // Only react to notifications for the current book
                if let bookHash = notification.userInfo?["bookHash"] as? String,
                   bookHash == self.book.contentHash {
                    Task {
                        await self.loadFromCache()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Load pagination state from cache using lightweight meta query (no page content loaded)
    private func loadFromCache() async {
        let viewSize = currentViewSize.width > 0 ? currentViewSize : persistenceService.loadLastViewSize()
        let cacheKey = PaginationCache.cacheKey(
            bookHash: book.contentHash,
            settings: coordinator.userSettings,
            viewSize: viewSize
        )

        do {
            if let meta = try persistenceService.loadPaginationMeta(
                bookHash: book.contentHash,
                settingsKey: cacheKey
            ) {
                let pageCount = try persistenceService.loadPageCount(
                    bookHash: book.contentHash,
                    settingsKey: cacheKey
                )

                await MainActor.run {
                    self.currentCacheKey = cacheKey
                    self.cachedPageCount = pageCount
                    self.totalPages = meta.isComplete ? pageCount : max(pageCount + 10, estimatedTotalPages())
                    self.isPaginationComplete = meta.isComplete
                    self.paginationProgress = Double(pageCount) / Double(self.estimatedTotalPages())
                    self.isLoading = false

                    debugPrint("📖 ReaderViewModel: Meta loaded - \(pageCount) pages (complete: \(meta.isComplete))")

                    // Update current page content
                    self.updatePageContent()

                    // Restore saved position after initial load
                    if pageCount > 0 && self.currentPage == 0 {
                        self.restoreSavedPosition()
                    }
                }
            } else {
                await MainActor.run {
                    self.showLoadingState()
                }
            }
        } catch {
            debugPrint("❌ ReaderViewModel: Error loading cache: \(error)")
            await MainActor.run {
                self.showLoadingState()
            }
        }
    }
    
    /// Show loading state when no cache is available
    @MainActor
    private func showLoadingState() {
        isLoading = false
        totalPages = estimatedTotalPages()
        pageContent = """
        Loading \(book.title)...
        
        The book is being processed in the background.
        Pages will appear as they become available.
        
        This may take a few moments for the first time.
        """
        
        debugPrint("⏳ ReaderViewModel: Showing loading state, waiting for pagination")
    }
    
    /// Estimate total pages based on file size, adjusted for text encoding
    private func estimatedTotalPages() -> Int {
        let enc = book.textEncoding.uppercased()
        // Multi-byte CJK encodings: ~2 bytes per character
        let bytesPerChar: Double = (enc.contains("GBK") || enc.contains("GB18030") || enc.contains("UTF-16")) ? 2.0 : 1.0
        let estimatedChars = Double(book.fileSize) / bytesPerChar
        // CJK text fits ~500 chars per page; Latin ~800
        let charsPerPage: Double = bytesPerChar > 1 ? 500 : 800
        return max(10, Int(estimatedChars / charsPerPage))
    }
    
    /// Update the page content based on current page
    private func updatePageContent() {
        let content = contentForPage(currentPage)
        guard content != pageContent else { return } // idempotency guard
        pageContent = content
        if isSpeaking {
            speech.stop()
            let rate = coordinator.userSettings.speechRate
            if let code = coordinator.userSettings.speechLanguageCode {
                speech.speak(pageContent, rate: rate, languageCode: code)
            } else {
                speech.speak(pageContent, rate: rate)
            }
        }
    }

    /// Get content for a specific page, fetching from SQLite on cache miss.
    /// Used by BookPagerView for adjacent pages and internally for current page.
    func contentForPage(_ page: Int) -> String {
        // Check LRU cache first
        if let cached = pageCache[page] {
            touchPageCache(page)
            return cached
        }
        // Fetch from SQLite (page_number is 1-based in DB)
        guard !currentCacheKey.isEmpty else {
            return !isPaginationComplete ? "Page \(page + 1) is being processed..." : ""
        }
        if let pageRange = try? persistenceService.loadPage(
            bookHash: book.contentHash,
            settingsKey: currentCacheKey,
            pageNumber: page + 1
        ) {
            insertPageCache(page, content: pageRange.content)
            return pageRange.content
        }
        return !isPaginationComplete ? "Page \(page + 1) is being processed..." : ""
    }

    // MARK: - LRU Page Cache

    private func touchPageCache(_ page: Int) {
        pageCacheOrder.removeAll { $0 == page }
        pageCacheOrder.append(page)
    }

    private func insertPageCache(_ page: Int, content: String) {
        pageCache[page] = content
        touchPageCache(page)
        // Evict oldest if over capacity
        while pageCacheOrder.count > pageCacheCapacity {
            let evicted = pageCacheOrder.removeFirst()
            pageCache.removeValue(forKey: evicted)
        }
    }

    private func clearPageCache() {
        pageCache.removeAll()
        pageCacheOrder.removeAll()
    }

    /// Navigate to a specific page
    func goToPage(_ page: Int) {
        let clampedPage = max(0, min(page, totalPages - 1))
        debugPrint("📖 ReaderViewModel: Navigating to page \(clampedPage + 1)")
        currentPage = clampedPage
    }
    
    /// Navigate to the next page
    func nextPage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }
    
    /// Navigate to the previous page
    func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
        }
    }
    
    /// Close the book and return to library
    func closeBook() {
        saveCurrentProgress()
        coordinator.navigateToLibrary()
    }
    
    /// Toggle text-to-speech
    func toggleSpeech() {
        // First-time prompt if language not chosen yet
        if coordinator.userSettings.speechLanguageCode == nil && !isSpeaking {
            shouldPresentTTSPicker = true
            return
        }
        if isSpeaking {
            speech.pause()
            isSpeaking = false
        } else {
            let text = pageContent
            let rate = coordinator.userSettings.speechRate
            if !text.isEmpty {
                if let code = coordinator.userSettings.speechLanguageCode {
                    speech.speak(text, rate: rate, languageCode: code)
                } else {
                    speech.speak(text, rate: rate)
                }
            }
            isSpeaking = true
        }
    }

    /// Confirm and save TTS language selection then start speaking
    func confirmTTSLanguageSelection(code: String) {
        var settings = coordinator.userSettings
        settings.speechLanguageCode = code
        coordinator.saveUserSettings(settings)
        shouldPresentTTSPicker = false

        // Auto-start speaking after selection
        let text = pageContent
        let rate = coordinator.userSettings.speechRate
        if !text.isEmpty {
            speech.speak(text, rate: rate, languageCode: code)
        }
        isSpeaking = true
    }
    
    // MARK: - View Size Management
    
    /// Update the view size for pagination calculations
    func updateViewSize(_ size: CGSize) {
        // Only update if integer width/height changed (material change)
        let oldW = Int(currentViewSize.width)
        let oldH = Int(currentViewSize.height)
        let newW = Int(size.width)
        let newH = Int(size.height)
        if oldW != newW || oldH != newH {
            debugPrint("📐 ReaderViewModel: View size changed to \(size) (material)")
            currentViewSize = size
            
            // Save the view size for background service keying
            persistenceService.saveLastViewSize(size)
            
            // Reload from cache with new size
            Task { await loadFromCache() }
        }
    }
    
    /// Update the content area size (view size minus padding)
    func updateContentSize(_ size: CGSize) {
        currentContentSize = size
    }
    
    // MARK: - Progress Management
    
    /// Load saved reading progress for this book
    private func loadSavedProgress() {
        currentReadingProgress = coordinator.getReadingProgress(for: book.contentHash)
        if let progress = currentReadingProgress {
            debugPrint("📖 ReaderViewModel: Loaded saved progress for \(book.title) - page \(progress.lastPageNumber ?? 0)")
        } else {
            debugPrint("📖 ReaderViewModel: No saved progress found for \(book.title), starting from beginning")
            currentReadingProgress = ReadingProgress.beginning(for: book.contentHash)
        }
    }
    
    /// Restore saved reading position after pagination
    private func restoreSavedPosition() {
        guard let progress = currentReadingProgress else { return }
        
        // If we have a saved page number and it's valid, use it
        if let savedPage = progress.lastPageNumber, savedPage < totalPages {
            currentPage = savedPage
            debugPrint("📖 ReaderViewModel: Restored to page \(savedPage)")
        }
    }
    
    /// Save current reading progress
    private func saveCurrentProgress() {
        guard var progress = currentReadingProgress else { return }
        
        // Calculate character index (simplified - using page number for now)
        let characterIndex = calculateCharacterIndex(for: currentPage)
        
        // Update progress
        progress.updatePosition(
            characterIndex: characterIndex,
            pageNumber: currentPage,
            totalPages: totalPages
        )
        
        // Save through coordinator
        coordinator.saveReadingProgress(progress)
        
        // Update our local copy
        currentReadingProgress = progress
        
        debugPrint("📖 ReaderViewModel: Saved progress for \(book.title) - page \(currentPage)")
    }
    
    /// Calculate character index for a given page using actual page boundaries from SQLite
    private func calculateCharacterIndex(for page: Int) -> Int {
        guard !currentCacheKey.isEmpty else {
            return page * 1000 // fallback
        }
        if let pageRange = try? persistenceService.loadPage(
            bookHash: book.contentHash,
            settingsKey: currentCacheKey,
            pageNumber: page + 1
        ) {
            return pageRange.startIndex
        }
        return page * 1000 // fallback
    }
    
    // MARK: - Cleanup
    
    deinit {
        speech.stop()
        debugPrint("♻️ ReaderViewModel: Deinitialized for book: \(book.title)")
    }
}