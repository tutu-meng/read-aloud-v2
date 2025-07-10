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
        setupObservers()
        loadBooks()
    }
    
    // MARK: - Methods
    
    /// Load books from storage
    func loadBooks() {
        // TODO: Implement loading books from PersistenceService
        // For now, adding sample book for UI testing
        
        // Check if sample book exists
        let sampleBookPath = Bundle.main.path(forResource: "alice_in_wonderland", ofType: "txt", inDirectory: "SampleBooks")
            ?? "Resources/SampleBooks/alice_in_wonderland.txt"
        
        let sampleBook = Book(
            title: "Alice's Adventures in Wonderland",
            fileURL: URL(fileURLWithPath: sampleBookPath),
            contentHash: "sample-alice-hash",
            importedDate: Date(),
            fileSize: 5102
        )
        
        books = [sampleBook]
    }
    
    /// Handle book selection
    func selectBook(_ book: Book) {
        coordinator.navigateToReader(with: book)
    }
    
    /// Handle file import from document picker
    func handleFileImport(_ fileURL: URL) {
        coordinator.handleFileImport(fileURL)
    }
    
    /// Add a new book to the library
    /// - Parameter book: The book to add
    @MainActor
    func addBook(_ book: Book) {
        debugPrint("📚 LibraryViewModel: Adding book: \(book.title)")
        
        // Check if book already exists (by content hash)
        if !books.contains(where: { $0.contentHash == book.contentHash }) {
            books.append(book)
            debugPrint("✅ LibraryViewModel: Book added successfully")
        } else {
            debugPrint("⚠️ LibraryViewModel: Book already exists with same content hash")
        }
    }
    
    /// Remove a book from the library
    /// - Parameter book: The book to remove
    func removeBook(_ book: Book) {
        books.removeAll { $0.id == book.id }
        debugPrint("🗑️ LibraryViewModel: Removed book: \(book.title)")
    }
    
    // MARK: - Private Methods
    
    /// Setup observers for notifications
    private func setupObservers() {
        // Listen for book added notifications
        NotificationCenter.default.publisher(for: .bookAdded)
            .compactMap { $0.userInfo?["book"] as? Book }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] book in
                Task { @MainActor in
                    self?.addBook(book)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Import a new book
    func importBook(from url: URL) {
        // TODO: Implement file import using FileProcessor
        print("Importing book from: \(url)")
    }
} 