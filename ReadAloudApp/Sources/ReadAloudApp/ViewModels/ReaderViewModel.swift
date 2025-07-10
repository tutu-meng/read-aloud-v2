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
    private var currentContentSize: CGSize = .zero
    private var currentTextSource: TextSource?
    private var currentPaginationService: PaginationService?
    
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
        guard let textSource = currentTextSource else { return }
        
        // Create a new PaginationService with current settings
        currentPaginationService = coordinator.makePaginationService(
            textSource: textSource,
            userSettings: coordinator.userSettings
        )
        
        // Get total page count
        totalPages = currentPaginationService?.totalPageCount() ?? 0
        
        // Use the new async paginateText method with Core Text calculations (BUG-1 FIX)
        if !fullBookContent.isEmpty {
            bookPages = await coordinator.makePaginationService(
                textSource: textSource,
                userSettings: coordinator.userSettings
            ).paginateText(
                content: fullBookContent,
                settings: coordinator.userSettings,
                viewSize: currentContentSize
            )
            
            totalPages = bookPages.count
        }
        
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
                    // Fallback pagination until view size is available
                    await MainActor.run {
                        self.currentPaginationService = self.coordinator.makePaginationService(
                            textSource: textSource,
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
    
    /// Extract text content from TextSource for display
    private func extractTextContent(from textSource: TextSource) async throws -> String {
        switch textSource {
        case .memoryMapped(let nsData):
            // Convert NSData to String
            guard let string = String(data: nsData as Data, encoding: .utf8) else {
                throw AppError.fileReadFailed(filename: book.title, underlyingError: nil)
            }
            return string
            
        case .streaming(let fileHandle):
            // Read from FileHandle
            let data = fileHandle.readDataToEndOfFile()
            guard let string = String(data: data, encoding: .utf8) else {
                throw AppError.fileReadFailed(filename: book.title, underlyingError: nil)
            }
            return string
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