//
//  ReaderViewModel.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI
import Combine

/// ReaderViewModel manages the state and logic for the reader view
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
    
    /// The book being read
    var book: Book
    private let coordinator: AppCoordinator
    private var cancellables = Set<AnyCancellable>()
    private var bookPages: [String] = []
    private var fullBookContent: String = ""
    private var currentViewSize: CGSize = .zero
    private var currentContentSize: CGSize = .zero
    private var currentTextSource: TextSource?
    private var currentPaginationService: PaginationService?
    private var currentReadingProgress: ReadingProgress?
    
    // MARK: - Initialization
    init(book: Book, coordinator: AppCoordinator) {
        self.book = book
        self.coordinator = coordinator
        
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
        debugPrint("📱 ReaderViewModel: Settings changed, triggering re-pagination")
        
        // Invalidate pagination cache if we have a service
        currentPaginationService?.invalidateCache()
        
        // Re-paginate with new settings if we have content
        if currentTextSource != nil && currentViewSize != .zero {
            Task {
                await repaginateContent()
            }
        }
    }
    
    // MARK: - Pagination Methods
    
    /// Re-paginate content with current settings (BUG-1 FIX - now async)
    private func repaginateContent() async {
        guard !fullBookContent.isEmpty else { return }
        
        // Create a new PaginationService with pre-extracted text content (encoding-aware)
        currentPaginationService = coordinator.makePaginationService(
            textContent: fullBookContent,
            userSettings: coordinator.userSettings
        )
        
        // Get total page count
        totalPages = currentPaginationService?.totalPageCount() ?? 0
        
        // Use the new async paginateText method with Core Text calculations (BUG-1 FIX)
        bookPages = await coordinator.makePaginationService(
            textContent: fullBookContent,
            userSettings: coordinator.userSettings
        ).paginateText(
            content: fullBookContent,
            settings: coordinator.userSettings,
            viewSize: currentContentSize
        )
        
        totalPages = bookPages.count
        
        // Ensure current page is valid
        if currentPage >= totalPages {
            currentPage = max(0, totalPages - 1)
        }
        
        // Update page content
        updatePageContent()
    }
    
    /// Update view size for pagination calculations
    func updateViewSize(_ size: CGSize) {
        guard size != currentViewSize else { return }
        
        currentViewSize = size
        currentContentSize = CGSize(width: size.width, height: size.height - 100)
        
        // Re-paginate if we have content (now async)
        if currentTextSource != nil {
            Task {
                await repaginateContent()
            }
        }
    }
    
    // MARK: - Methods
    
    /// Load and paginate the book
    func loadBook() {
        isLoading = true
        
        // Load saved reading progress first
        loadSavedProgress()
        
        // Use FileProcessor to load the book content
        Task {
            do {
                // Load text using FileProcessor
                let textSource = try await coordinator.fileProcessor.loadText(from: book.fileURL)
                
                // Extract text content for display
                let content = try await extractTextContent(from: textSource)
                
                await MainActor.run {
                    self.currentTextSource = textSource
                    self.fullBookContent = content
                    self.isLoading = false
                }
                
                // Perform pagination after updating the main actor properties
                if self.currentViewSize != .zero {
                    await self.repaginateContent()
                } else {
                    // Fallback pagination until view size is available (using encoding-aware approach)
                    await MainActor.run {
                        self.currentPaginationService = self.coordinator.makePaginationService(
                            textContent: content,
                            userSettings: self.coordinator.userSettings
                        )
                    }
                    
                    let pages = await self.currentPaginationService?.paginateText(
                        content: content,
                        settings: self.coordinator.userSettings,
                        viewSize: self.currentContentSize // Default iPhone size
                    ) ?? []
                    
                    await MainActor.run {
                        self.bookPages = pages
                        self.totalPages = self.bookPages.count
                        self.updatePageContent()
                        
                        // Restore saved page position after pagination
                        self.restoreSavedPosition()
                    }
                }
            } catch {
                // Handle loading error
                await MainActor.run {
                    self.isLoading = false
                    self.totalPages = 10 // Simulate 10 pages for testing
                    self.bookPages = []
                    self.updatePageContent()
                    
                    // Report error to coordinator
                    self.coordinator.handleError(error)
                }
            }
        }
    }
    
    /// Extract text content from TextSource for display using Book's encoding
    private func extractTextContent(from textSource: TextSource) async throws -> String {
        // Use the FileProcessor's encoding-aware extraction method
        return try await coordinator.fileProcessor.extractTextContent(
            from: textSource,
            using: book.stringEncoding,
            filename: book.title
        )
    }
    
    /// Update the page content based on current page
    private func updatePageContent() {
        // Use actual book content if available
        if !bookPages.isEmpty && currentPage < bookPages.count {
            pageContent = bookPages[currentPage]
        } else {
            // Fallback to placeholder content
            pageContent = """
            Page \(currentPage + 1) of \(book.title)
            
            This is placeholder content for page \(currentPage + 1).
            
            In a real implementation, this would contain the actual paginated text from the book file. The content would be calculated by the PaginationService based on the current font settings and view dimensions.
            
            Font: \(coordinator.userSettings.fontName)
            Size: \(coordinator.userSettings.fontSize)pt
            Line Spacing: \(coordinator.userSettings.lineSpacing)x
            
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
            
            Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
            """
        }
    }
    
    /// Navigate to a specific page
    func goToPage(_ page: Int) {
        guard page >= 0 && page < totalPages else { return }
        currentPage = page
    }
    
    /// Start/stop text-to-speech
    func toggleSpeech() {
        isSpeaking.toggle()
        // TODO: Implement using SpeechService
    }
    
    /// Go back to library
    func goBackToLibrary() {
        coordinator.navigateToLibrary()
    }
    
    /// Create a SettingsViewModel for the settings sheet
    func makeSettingsViewModel() -> SettingsViewModel {
        return coordinator.makeSettingsViewModel()
    }
    
    // MARK: - Deinit
    
    deinit {
        // Save progress when leaving the reader
        saveCurrentProgress()
        debugPrint("♻️ ReaderViewModel: Deinitializing and saving progress")
    }
    
    // MARK: - Reading Progress Methods
    
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
        // TODO: In the future, we could use lastReadCharacterIndex to find the exact page
        // For now, using page number is sufficient
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
        // Simple calculation: estimate characters per page
        // In a real implementation, this would use the actual text content
        let estimatedCharsPerPage = fullBookContent.count / max(totalPages, 1)
        return page * estimatedCharsPerPage
    }
    
    // MARK: - Encoding Management Methods
    
    /// Change the book's encoding and reprocess the content
    /// - Parameter newEncoding: The new encoding to use
    func changeBookEncoding(to newEncoding: String) {
        debugPrint("📄 ReaderViewModel: Changing book encoding to: \(newEncoding)")
        
        // Update the book with new encoding
        let updatedBook = book.withEncoding(newEncoding)
        
        // Save the updated book to persistence
        coordinator.updateBook(updatedBook)
        
        // Update our local book reference
        self.book = updatedBook
        
        // Clear current content and pagination cache
        clearPaginationCache()
        
        // Reload the book with new encoding
        loadBook()
    }
    
    /// Get available encodings for the UI
    var availableEncodings: [String] {
        return Book.supportedEncodings
    }
    
    /// Get the current book's encoding
    var currentEncoding: String {
        return book.textEncoding
    }
    
    /// Clear pagination cache to force re-processing
    private func clearPaginationCache() {
        debugPrint("📄 ReaderViewModel: Clearing pagination cache")
        currentTextSource = nil
        currentPaginationService = nil
        bookPages = []
        fullBookContent = ""
        totalPages = 0
        currentPage = 0
        pageContent = ""
    }
} 