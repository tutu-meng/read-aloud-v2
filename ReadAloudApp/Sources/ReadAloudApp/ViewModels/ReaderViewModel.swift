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
                lastUserInteractionTime = Date()
                NotificationCenter.default.post(name: .userInteractionOccurred, object: nil)
                updatePageContent()
                debouncedSaveProgress()
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
    /// Whether the reader is showing seed-window content (approximate position, not yet reconciled)
    @Published var isSeedMode = false

    /// Track last user interaction for pagination coordination
    @Published private(set) var lastUserInteractionTime = Date.distantPast
    
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
    private var viewSizeDebounceTask: Task<Void, Never>?
    private var progressSaveDebounceTask: Task<Void, Never>?
    private var settingsDebounceTask: Task<Void, Never>?
    private var loadBookTask: Task<Void, Never>?
    private let speech: SpeechSynthesizing = SystemSpeechService()

    // MARK: - Seed Window State
    /// Seed pages computed from the saved character position (in-memory only)
    private var seedPages: [(content: String, range: NSRange)] = []
    /// Character index used as the seed anchor
    private var seedAnchorCharIndex: Int = 0
    /// The page number where seed window starts (fixed anchor for offset calculation)
    private var seedStartPage: Int = 0
    
    // MARK: - Initialization
    init(book: Book, coordinator: AppCoordinator) {
        self.book = book
        self.coordinator = coordinator
        self.persistenceService = PersistenceService.shared

        setupSettingsObservation()
        setupAppLifecycleObservation()
        setupPaginationObservation()
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
    
    /// Handle settings changes that affect layout (debounced to avoid cascade from rapid changes)
    private func handleSettingsChange() {
        settingsDebounceTask?.cancel()
        settingsDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
            guard !Task.isCancelled else { return }
            await MainActor.run {
                debugPrint("📱 ReaderViewModel: Settings changed, will reload from new cache")
                self.clearPageCache()
                self.clearSeedState()
                self.currentCacheKey = ""
                self.cachedPageCount = 0
                self.isPaginationComplete = false
                self.loadBook()
            }
        }
    }
    
    // MARK: - Methods
    
    /// Load book from pagination cache
    func loadBook() {
        isLoading = true

        // Load saved reading progress first
        loadSavedProgress()

        // Cancel any in-flight load task before starting a new one
        loadBookTask?.cancel()
        loadBookTask = Task {
            await loadFromCache()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.requestSeedIfNeeded()
            }
        }
    }

    /// Observe notifications from BackgroundPaginationService
    private func setupPaginationObservation() {
        NotificationCenter.default.publisher(for: .paginationBatchCompleted)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let bookHash = notification.userInfo?["bookHash"] as? String,
                   bookHash == self.book.contentHash {
                    Task {
                        await self.loadFromCache()
                    }
                }
            }
            .store(in: &cancellables)

        // Seed window is ready — enter seed mode
        NotificationCenter.default.publisher(for: .seedWindowReady)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let bookHash = notification.userInfo?["bookHash"] as? String,
                   bookHash == self.book.contentHash,
                   let serialized = notification.userInfo?["seedPages"] as? [[String: Any]] {
                    DispatchQueue.main.async {
                        self.handleSeedWindowReady(serialized)
                    }
                }
            }
            .store(in: &cancellables)

        // Background pagination has caught up to the seed anchor — reconcile page number
        NotificationCenter.default.publisher(for: .seedReconciled)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let bookHash = notification.userInfo?["bookHash"] as? String,
                   bookHash == self.book.contentHash,
                   let realPage = notification.userInfo?["realPageNumber"] as? Int {
                    DispatchQueue.main.async {
                        self.handleSeedReconciled(realPageNumber: realPage)
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
    
    /// Estimate total pages based on actual pagination data when available, falling back to file-size heuristic.
    private func estimatedTotalPages() -> Int {
        // If we have partial pagination data, extrapolate from actual chars-per-page
        if cachedPageCount > 0, !currentCacheKey.isEmpty,
           let meta = try? persistenceService.loadPaginationMeta(
               bookHash: book.contentHash,
               settingsKey: currentCacheKey
           ), meta.lastProcessedIndex > 0 {
            let charsPerPage = Double(meta.lastProcessedIndex) / Double(cachedPageCount)
            let enc = book.textEncoding.uppercased()
            let bytesPerChar: Double = (enc.contains("GBK") || enc.contains("GB18030") || enc.contains("UTF-16")) ? 2.0 : 1.0
            let estimatedTotalChars = Double(book.fileSize) / bytesPerChar
            let estimate = Int(estimatedTotalChars / charsPerPage)
            return max(cachedPageCount, estimate)
        }

        // Fallback: pure file-size heuristic
        let enc = book.textEncoding.uppercased()
        let bytesPerChar: Double = (enc.contains("GBK") || enc.contains("GB18030") || enc.contains("UTF-16")) ? 2.0 : 1.0
        let estimatedChars = Double(book.fileSize) / bytesPerChar
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

        // In seed mode, serve seed content for pages within the seed window
        if isSeedMode {
            let seedIndex = page - seedStartPage
            if seedIndex >= 0 && seedIndex < seedPages.count {
                return seedPages[seedIndex].content
            }
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
    
    /// Update the view size for pagination calculations.
    /// Debounced by 0.3s to wait for geometry to settle (navigation bar, safe area).
    func updateViewSize(_ size: CGSize) {
        // Only update if integer width/height changed (material change)
        let oldW = Int(currentViewSize.width)
        let oldH = Int(currentViewSize.height)
        let newW = Int(size.width)
        let newH = Int(size.height)
        if oldW != newW || oldH != newH {
            debugPrint("📐 ReaderViewModel: View size changed to \(size) (material), debouncing...")
            currentViewSize = size

            // Cancel any pending debounce and wait for geometry to settle
            viewSizeDebounceTask?.cancel()
            viewSizeDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
                guard !Task.isCancelled else { return }

                debugPrint("📐 ReaderViewModel: View size settled at \(size)")
                persistenceService.saveLastViewSize(size)
                await loadFromCache()
            }
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
    
    /// Debounced progress save: wait 1 second after last page change to avoid blocking UI
    private func debouncedSaveProgress() {
        // Cancel any pending save
        progressSaveDebounceTask?.cancel()

        // Schedule new save after user stops flipping pages
        progressSaveDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.saveCurrentProgress()
            }
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
    
    // MARK: - Seed Window

    /// Request a seed window if the user has a saved position that isn't cached yet.
    private func requestSeedIfNeeded() {
        guard let progress = currentReadingProgress,
              progress.lastReadCharacterIndex > 0 else { return }

        // Check if the saved position is already covered by the cache
        if let savedPage = progress.lastPageNumber, savedPage < cachedPageCount {
            return // Cache already covers the saved position
        }

        let viewSize = currentViewSize.width > 0 ? currentViewSize : persistenceService.loadLastViewSize()
        guard viewSize.width > 0 && viewSize.height > 0 else { return }

        seedAnchorCharIndex = progress.lastReadCharacterIndex
        debugPrint("🌱 ReaderViewModel: Requesting seed window at char \(seedAnchorCharIndex)")
        coordinator.requestSeedWindow(
            for: book,
            anchorCharIndex: seedAnchorCharIndex,
            settings: coordinator.userSettings,
            viewSize: viewSize
        )
    }

    /// Handle seed window ready notification.
    private func handleSeedWindowReady(_ serialized: [[String: Any]]) {
        var pages: [(content: String, range: NSRange)] = []
        for dict in serialized {
            guard let content = dict["content"] as? String,
                  let location = dict["location"] as? Int,
                  let length = dict["length"] as? Int else { continue }
            pages.append((content: content, range: NSRange(location: location, length: length)))
        }
        guard !pages.isEmpty else { return }

        seedPages = pages
        isSeedMode = true
        isLoading = false
        totalPages = max(totalPages, estimatedTotalPages())

        // Restore the saved page (keep the saved page number for now; it will be reconciled later)
        if let savedPage = currentReadingProgress?.lastPageNumber, savedPage > 0 {
            currentPage = min(savedPage, totalPages - 1)
        }
        seedStartPage = currentPage

        updatePageContent()
        debugPrint("🌱 ReaderViewModel: Entered seed mode with \(pages.count) pages at saved position")
    }

    /// Handle reconciliation: background pagination has reached the seed anchor.
    private func handleSeedReconciled(realPageNumber: Int) {
        guard isSeedMode else { return }
        debugPrint("🎯 ReaderViewModel: Reconciling seed → real page \(realPageNumber)")

        // Switch from seed mode to normal mode
        clearSeedState()

        // Jump to the real page number (content will be the same since it starts at the same char index)
        currentPage = realPageNumber
    }

    private func clearSeedState() {
        isSeedMode = false
        seedPages = []
        seedAnchorCharIndex = 0
        seedStartPage = 0
    }

    /// Approximate reading percentage for the page indicator in seed mode.
    var seedReadingPercentage: Int {
        guard seedAnchorCharIndex > 0 else { return 0 }
        let enc = book.textEncoding.uppercased()
        let bytesPerChar: Double = (enc.contains("GBK") || enc.contains("GB18030") || enc.contains("UTF-16")) ? 2.0 : 1.0
        let estimatedTotalChars = Double(book.fileSize) / bytesPerChar
        guard estimatedTotalChars > 0 else { return 0 }
        return min(99, max(1, Int(Double(seedAnchorCharIndex) / estimatedTotalChars * 100)))
    }

    // MARK: - Cleanup

    deinit {
        speech.stop()
        debugPrint("♻️ ReaderViewModel: Deinitialized for book: \(book.title)")
    }
}