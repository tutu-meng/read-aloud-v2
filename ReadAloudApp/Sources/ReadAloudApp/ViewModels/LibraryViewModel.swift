//
//  LibraryViewModel.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI
import Combine
import CryptoKit

/// LibraryViewModel manages the state and logic for the library view
class LibraryViewModel: ObservableObject {
    // MARK: - Properties
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let coordinator: AppCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Encoding Selection Properties
    @Published var showingEncodingSelection = false
    @Published var bookPendingEncoding: (url: URL, title: String)?
    
    // MARK: - Initialization
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        setupObservers()
        
        // Load books asynchronously
        Task { @MainActor in
            loadBooks()
        }
    }
    
    // MARK: - Methods
    
    /// Load books from persistent storage
    @MainActor
    func loadBooks() {
        isLoading = true
        
        Task {
            do {
                // Load books from persistent library only
                let finalBooks = await coordinator.loadBookLibrary()
                
                await MainActor.run {
                    self.books = finalBooks
                    self.isLoading = false
                    debugPrint("📚 LibraryViewModel: Loaded \(finalBooks.count) books from persistent library")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to load books: \(error.localizedDescription)"
                    debugPrint("❌ LibraryViewModel: Failed to load books: \(error)")
                }
            }
        }
    }
    
    // Documents migration path removed: encoding must be chosen by user during import
    
    @MainActor
    
    /// Handle book selection
    func selectBook(_ book: Book) {
        coordinator.navigateToReader(with: book)
    }
    
    /// Remove a book from the library
    /// - Parameters:
    ///   - book: The book to remove
    ///   - deleteFile: Whether to delete the associated file (default: false)
    @MainActor
    func removeBook(_ book: Book, deleteFile: Bool = false) {
        debugPrint("📚 LibraryViewModel: Removing book: \(book.title)")
        
        // Remove from local books array
        books.removeAll { $0.id == book.id }
        
        // Remove from persistent library and optional file deletion
        Task {
            await coordinator.removeBookFromLibrary(book)
            if deleteFile {
                deleteBookFile(book)
            }
        }
        
        // Optionally delete the file
        if deleteFile {
            deleteBookFile(book)
        }
        
        debugPrint("✅ LibraryViewModel: Book removed successfully")
    }    
    
    /// Delete the file associated with a book
    /// - Parameter book: The book whose file should be deleted
    private func deleteBookFile(_ book: Book) {
        do {
            // Only delete files in the Documents directory (imported files)
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let bookFileURL = book.fileURL
            
            // Check if the file is in the Documents directory
            if bookFileURL.path.hasPrefix(documentsURL.path) {
                try FileManager.default.removeItem(at: bookFileURL)
                debugPrint("🗑️ LibraryViewModel: Deleted file: \(bookFileURL.lastPathComponent)")
            } else {
                debugPrint("⚠️ LibraryViewModel: Skipping file deletion for non-imported file: \(bookFileURL.lastPathComponent)")
            }
        } catch {
            debugPrint("❌ LibraryViewModel: Failed to delete file for book '\(book.title)': \(error)")
        }
    }
    
    // MARK: - Encoding Selection Methods
    
    /// Handle file import from document picker
    /// - Parameter fileURL: The selected file URL
    @MainActor
    func handleFileImport(_ fileURL: URL) {
        debugPrint("📚 LibraryViewModel: Handling file import: \(fileURL.lastPathComponent)")
        
        let bookTitle = fileURL.deletingPathExtension().lastPathComponent
        
        // Check if this book already exists (by checking if we've processed this file before)
        let existingBook = books.first { book in
            book.title == bookTitle || book.fileURL.lastPathComponent == fileURL.lastPathComponent
        }
        
        if let existingBook = existingBook {
            // Book already exists, navigate to it directly
            debugPrint("📚 LibraryViewModel: Book already exists, navigating to existing book")
            coordinator.navigateToReader(with: existingBook)
        } else {
            // New book, show encoding selection
            debugPrint("📚 LibraryViewModel: New book, showing encoding selection")
            bookPendingEncoding = (url: fileURL, title: bookTitle)
            showingEncodingSelection = true
        }
    }
    
    /// Handle encoding selection for a pending book
    /// - Parameter encoding: The selected encoding
    @MainActor
    func handleEncodingSelection(_ encoding: String) {
        guard let pendingBook = bookPendingEncoding else {
            debugPrint("❌ LibraryViewModel: No pending book for encoding selection")
            return
        }
        
        debugPrint("📚 LibraryViewModel: Creating book with encoding: \(encoding)")
        
        Task {
            do {
                let book = try await createBook(from: pendingBook.url, with: encoding)
                
                // Add to persistent library
                await coordinator.addBookToLibrary(book)
                
                await MainActor.run {
                    self.books.append(book)
                    self.books.sort { $0.importedDate > $1.importedDate }
                    coordinator.navigateToReader(with: book)
                    clearEncodingSelection()
                }
            } catch {
                await MainActor.run {
                    debugPrint("❌ LibraryViewModel: Failed to create book: \(error)")
                    clearEncodingSelection()
                }
            }
        }
    }
    
    /// Cancel encoding selection
    @MainActor
    func cancelEncodingSelection() {
        clearEncodingSelection()
    }
    
    /// Clear encoding selection state
    @MainActor
    private func clearEncodingSelection() {
        showingEncodingSelection = false
        bookPendingEncoding = nil
    }
    
    /// Create a book from URL with specified encoding
    /// - Parameters:
    ///   - url: The file URL
    ///   - encoding: The text encoding to use
    /// - Returns: The created Book
    private func createBook(from url: URL, with encoding: String) async throws -> Book {
        let fileProcessor = FileProcessor()
        
        // Create book with specified encoding
        let book = try await fileProcessor.createBook(from: url, encoding: encoding)
        
        debugPrint("✅ LibraryViewModel: Book created successfully with \(encoding) encoding")
        return book
    }
    
    // MARK: - Private Methods
    
    /// Setup observers for notifications
    private func setupObservers() {
        // Listen for book added notifications
        NotificationCenter.default.publisher(for: .bookAdded)
            .compactMap { $0.userInfo?["book"] as? Book }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] book in
                // Already on main thread due to receive(on:)
                Task { @MainActor in
                    self?.loadBooks()
                }
            }
            .store(in: &cancellables)
    }
} 