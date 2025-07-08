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
    
    // MARK: - Initialization
    init(book: Book, coordinator: AppCoordinator) {
        self.book = book
        self.coordinator = coordinator
        loadBook()
    }
    
    // MARK: - Methods
    
    /// Load and paginate the book
    func loadBook() {
        // TODO: Implement using FileProcessor and PaginationService
        // For now, try to load actual file content for UI testing
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Try to load the actual file content
                let content = try String(contentsOf: self.book.fileURL, encoding: .utf8)
                
                // Simple pagination: split into chunks of approximately 500 characters
                let chunkSize = 500
                var pages: [String] = []
                var currentIndex = content.startIndex
                
                while currentIndex < content.endIndex {
                    let endIndex = content.index(currentIndex, offsetBy: chunkSize, limitedBy: content.endIndex) ?? content.endIndex
                    let pageContent = String(content[currentIndex..<endIndex])
                    pages.append(pageContent)
                    currentIndex = endIndex
                }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.totalPages = pages.count
                    self.bookPages = pages
                    self.updatePageContent()
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
            
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
            
            Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
            """
        }
    }
    
    /// Navigate to a specific page
    func goToPage(_ page: Int) {
        guard page >= 0 && page < totalPages else { return }
        currentPage = page
        // TODO: Load page content
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
} 