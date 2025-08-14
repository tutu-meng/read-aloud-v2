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
    
    /// The book being read
    var book: Book
    let coordinator: AppCoordinator
    private let persistenceService: PersistenceService
    private var cancellables = Set<AnyCancellable>()
    private var bookPages: [String] = []
    private var currentViewSize: CGSize = .zero
    private var currentContentSize: CGSize = .zero
    private var currentReadingProgress: ReadingProgress?
    private var cacheCheckTimer: Timer?
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
        
        // Stop current cache checking
        cacheCheckTimer?.invalidate()
        cacheCheckTimer = nil
        
        // Clear current pages
        bookPages = []
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
        
        // Simply load from cache
        Task {
            await loadFromCache()
            
            // Set up periodic cache checking
            await MainActor.run {
                self.cacheCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                    Task {
                        await self?.loadFromCache()
                    }
                }
            }
        }
    }
    
    /// Load pages from pagination cache
    private func loadFromCache() async {
        let viewSize = currentViewSize.width > 0 ? currentViewSize : persistenceService.loadLastViewSize()
        let cacheKey = PaginationCache.cacheKey(
            bookHash: book.contentHash,
            settings: coordinator.userSettings,
            viewSize: viewSize
        )
        
        do {
            if let cache = try persistenceService.loadPaginationCache(
                bookHash: book.contentHash,
                settingsKey: cacheKey
            ) {
                await MainActor.run {
                    // Update UI from cache
                    self.bookPages = cache.pages.map { $0.content }
                    self.totalPages = cache.isComplete ? self.bookPages.count : max(self.bookPages.count + 10, estimatedTotalPages())
                    self.isPaginationComplete = cache.isComplete
                    self.paginationProgress = Double(cache.pages.count) / Double(self.estimatedTotalPages())
                    self.isLoading = false
                    
                    debugPrint("📖 ReaderViewModel: Loaded \(self.bookPages.count) pages from cache (complete: \(cache.isComplete))")
                    
                    // Update current page content if needed
                    if self.currentPage < self.bookPages.count {
                        self.updatePageContent()
                    }
                    
                    // Restore saved position after initial load
                    if self.bookPages.count > 0 && self.currentPage == 0 {
                        self.restoreSavedPosition()
                    }
                    
                    // Stop checking if complete
                    if cache.isComplete {
                        self.cacheCheckTimer?.invalidate()
                        self.cacheCheckTimer = nil
                    }
                }
            } else {
                // No cache yet, show loading state
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
    
    /// Estimate total pages based on file size
    private func estimatedTotalPages() -> Int {
        // Rough estimate: ~2000 characters per page
        let charsPerPage = 2000
        let estimatedChars = Int(book.fileSize)
        return max(10, estimatedChars / charsPerPage)
    }
    
    /// Update the page content based on current page
    private func updatePageContent() {
        // Use actual book content if available
        if !bookPages.isEmpty && currentPage < bookPages.count {
            pageContent = bookPages[currentPage]
            print("pageContent: \(pageContent)")
            if isSpeaking {
                speech.stop()
                let rate = coordinator.userSettings.speechRate
                speech.speak(pageContent, rate: rate)
            }
        } else if !isPaginationComplete {
            // Show loading message for unpaginated pages
            pageContent = """
            Page \(currentPage + 1) is being processed...
            
            Please wait while the background service prepares this page.
            
            You can navigate to already processed pages while waiting.
            """
        } else {
            // Shouldn't happen, but provide fallback
            pageContent = "Page \(currentPage + 1) of \(book.title)"
        }
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
        
        // Stop cache checking
        cacheCheckTimer?.invalidate()
        cacheCheckTimer = nil
        
        coordinator.navigateToLibrary()
    }
    
    /// Toggle text-to-speech
    func toggleSpeech() {
        if isSpeaking {
            speech.pause()
            isSpeaking = false
        } else {
            let text = pageContent
            let rate = coordinator.userSettings.speechRate
            if !text.isEmpty {
                speech.speak(text, rate: rate)
            }
            isSpeaking = true
        }
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
    
    /// Calculate character index for a given page (simplified implementation)
    private func calculateCharacterIndex(for page: Int) -> Int {
        // For now, just estimate based on average page length
        // In a real implementation, this would use actual page boundaries
        let avgCharsPerPage = 1000
        return page * avgCharsPerPage
    }
    
    // MARK: - Cleanup
    
    deinit {
        cacheCheckTimer?.invalidate()
        speech.stop()
        debugPrint("♻️ ReaderViewModel: Deinitialized for book: \(book.title)")
    }
}