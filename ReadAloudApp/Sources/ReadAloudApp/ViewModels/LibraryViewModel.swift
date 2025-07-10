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
    
    /// Load books from storage
    @MainActor
    func loadBooks() {
        isLoading = true
        
        Task {
            do {
                let loadedBooks = try await loadBooksFromDocuments()
                
                await MainActor.run {
                    self.books = loadedBooks
                    self.isLoading = false
                    debugPrint("📚 LibraryViewModel: Loaded \(loadedBooks.count) books from storage")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to load books: \(error.localizedDescription)"
                    debugPrint("❌ LibraryViewModel: Failed to load books: \(error)")
                    
                    // Fallback to sample book for testing
                    self.loadSampleBook()
                }
            }
        }
    }
    
    /// Load books from the app's Documents directory
    /// This method scans the Documents directory for imported text files
    /// and creates Book objects for each discovered file
    private func loadBooksFromDocuments() async throws -> [Book] {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileManager = FileManager.default
        
        // Get all files in the Documents directory
        let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: .skipsHiddenFiles)
        
        // Filter for text files
        let textFiles = fileURLs.filter { url in
            let pathExtension = url.pathExtension.lowercased()
            return pathExtension == "txt" || pathExtension == "text"
        }
        
        var books: [Book] = []
        
        // Create Book objects for each text file
        for fileURL in textFiles {
            do {
                let book = try await createBookFromFile(fileURL)
                books.append(book)
            } catch {
                debugPrint("⚠️ LibraryViewModel: Failed to create book from file \(fileURL.lastPathComponent): \(error)")
                // Continue with other files instead of failing completely
            }
        }
        
        // Sort books by import date (newest first)
        books.sort { $0.importedDate > $1.importedDate }
        
        // If no books found, add sample book for testing
        if books.isEmpty {
            debugPrint("📚 LibraryViewModel: No books found in Documents, adding sample book")
            books.append(createSampleBook())
        }
        
        return books
    }
    
    /// Create a Book object from a file URL
    private func createBookFromFile(_ fileURL: URL) async throws -> Book {
        let fileManager = FileManager.default
        
        // Get file attributes
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let creationDate = attributes[.creationDate] as? Date ?? Date()
        
        // Calculate content hash
        let contentHash = try await calculateContentHash(for: fileURL)
        
        // Create book title from filename
        let title = fileURL.deletingPathExtension().lastPathComponent
        
        return Book(
            id: UUID(),
            title: title,
            fileURL: fileURL,
            contentHash: contentHash,
            importedDate: creationDate,
            fileSize: fileSize,
            textEncoding: "UTF-8" // Default to UTF-8, user will be asked to select if needed
        )
    }
    
    /// Calculate SHA256 hash for file content
    private func calculateContentHash(for url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let data = try Data(contentsOf: url)
                    let hash = SHA256.hash(data: data)
                    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                    continuation.resume(returning: hashString)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Create the sample book for testing
    private func createSampleBook() -> Book {
        let sampleBookPath = Bundle.main.path(forResource: "alice_in_wonderland", ofType: "txt", inDirectory: "SampleBooks")
            ?? "Resources/SampleBooks/alice_in_wonderland.txt"
        
        return Book(
            title: "Alice's Adventures in Wonderland",
            fileURL: URL(fileURLWithPath: sampleBookPath),
            contentHash: "sample-alice-hash",
            importedDate: Date(),
            fileSize: 5102
        )
    }
    
    /// Load sample book as fallback
    @MainActor
    private func loadSampleBook() {
        books = [createSampleBook()]
    }
    
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
        
        // Remove from books array
        books.removeAll { $0.id == book.id }
        
        // Optionally delete the file
        if deleteFile {
            deleteBookFile(book)
        }
        
        debugPrint("✅ LibraryViewModel: Book removed successfully")
    }
    
    /// Remove multiple books from the library
    /// - Parameters:
    ///   - booksToRemove: Array of books to remove
    ///   - deleteFiles: Whether to delete the associated files (default: false)
    @MainActor
    func removeBooks(_ booksToRemove: [Book], deleteFiles: Bool = false) {
        debugPrint("📚 LibraryViewModel: Removing \(booksToRemove.count) books")
        
        let idsToRemove = Set(booksToRemove.map { $0.id })
        books.removeAll { idsToRemove.contains($0.id) }
        
        // Optionally delete the files
        if deleteFiles {
            for book in booksToRemove {
                deleteBookFile(book)
            }
        }
        
        debugPrint("✅ LibraryViewModel: \(booksToRemove.count) books removed successfully")
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
    
    /// Import a new book
    func importBook(from url: URL) {
        // TODO: Implement file import using FileProcessor
        print("Importing book from: \(url)")
    }
} 