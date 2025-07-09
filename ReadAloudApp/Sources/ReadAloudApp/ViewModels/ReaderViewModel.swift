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
            }
        }
    }
    @Published var totalPages = 0
    @Published var pageContent = ""
    @Published var isLoading = true
    @Published var isSpeaking = false
    
    let book: Book
    private let coordinator: AppCoordinator
    private var cancellables = Set<AnyCancellable>()
    private var bookPages: [String] = []
    private var fullBookContent: String = ""
    private var currentViewSize: CGSize = .zero
    
    // MARK: - Initialization
    init(book: Book, coordinator: AppCoordinator) {
        self.book = book
        self.coordinator = coordinator
        
        setupSettingsObservation()
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
    
    /// Handle settings changes that affect layout
    private func handleSettingsChange() {
        debugPrint("📱 ReaderViewModel: Settings changed, triggering re-pagination")
        
        // Invalidate pagination cache
        coordinator.paginationService.invalidateCache()
        
        // Re-paginate with new settings if we have content
        if !fullBookContent.isEmpty && currentViewSize != .zero {
            repaginateContent()
        }
    }
    
    // MARK: - Pagination Methods
    
    /// Re-paginate content with current settings
    private func repaginateContent() {
        guard !fullBookContent.isEmpty else { return }
        
        // Use PaginationService to paginate content
        bookPages = coordinator.paginationService.paginateText(
            content: fullBookContent,
            settings: coordinator.userSettings,
            viewSize: currentViewSize
        )
        
        // Update total pages
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
        
        // Re-paginate if we have content
        if !fullBookContent.isEmpty {
            repaginateContent()
        }
    }
    
    // MARK: - Methods
    
    /// Load and paginate the book
    func loadBook() {
        isLoading = true
        
        // TODO: Implement using FileProcessor
        // For now, try to load actual file content for UI testing
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Try to load the actual file content
                let content = try String(contentsOf: self.book.fileURL, encoding: .utf8)
                
                DispatchQueue.main.async {
                    self.fullBookContent = content
                    self.isLoading = false
                    
                    // Initial pagination (will use default view size initially)
                    if self.currentViewSize != .zero {
                        self.repaginateContent()
                    } else {
                        // Fallback pagination until view size is available
                        self.bookPages = self.coordinator.paginationService.paginateText(
                            content: content,
                            settings: self.coordinator.userSettings,
                            viewSize: CGSize(width: 375, height: 600) // Default iPhone size
                        )
                        self.totalPages = self.bookPages.count
                        self.updatePageContent()
                    }
                }
            } catch {
                // Fallback to placeholder content if file can't be loaded
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.totalPages = 10 // Simulate 10 pages for testing
                    self.bookPages = []
                    self.updatePageContent()
                }
            }
        }
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
} 