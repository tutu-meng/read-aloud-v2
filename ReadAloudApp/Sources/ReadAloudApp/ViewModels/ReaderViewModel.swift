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
        // For now, simulate multiple pages for UI testing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.totalPages = 10 // Simulate 10 pages for testing
            self.updatePageContent()
        }
    }
    
    /// Update the page content based on current page
    private func updatePageContent() {
        // Simulate different content for each page
        pageContent = """
        Page \(currentPage + 1) of \(book.title)
        
        This is placeholder content for page \(currentPage + 1).
        
        In a real implementation, this would contain the actual paginated text from the book file. The content would be calculated by the PaginationService based on the current font settings and view dimensions.
        
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
        
        Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
        """
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