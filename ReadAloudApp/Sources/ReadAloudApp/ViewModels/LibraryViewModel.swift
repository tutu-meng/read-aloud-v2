//
//  LibraryViewModel.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI
import Combine

/// LibraryViewModel manages the state and logic for the library view
class LibraryViewModel: ObservableObject {
    // MARK: - Properties
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let coordinator: AppCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        loadBooks()
    }
    
    // MARK: - Methods
    
    /// Load books from storage
    func loadBooks() {
        // TODO: Implement loading books from PersistenceService
        // For now, using empty array
        books = []
    }
    
    /// Handle book selection
    func selectBook(_ book: Book) {
        coordinator.navigateToReader(with: book)
    }
    
    /// Import a new book
    func importBook(from url: URL) {
        // TODO: Implement file import using FileProcessor
        print("Importing book from: \(url)")
    }
} 