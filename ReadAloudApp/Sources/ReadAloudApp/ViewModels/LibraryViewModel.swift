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
    
    // MARK: - Initialization
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        setupObservers()
        loadBooks()
    }
    
    // MARK: - Methods
    
    /// Load books from storage
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
        
        // Detect encoding using FileProcessor
        let fileProcessor = FileProcessor()
        let detectedEncoding = try await fileProcessor.detectBestEncoding(for: fileURL)
        
        // Create book title from filename
        let title = fileURL.deletingPathExtension().lastPathComponent
        
        return Book(
            id: UUID(),
            title: title,
            fileURL: fileURL,
            contentHash: contentHash,
            importedDate: creationDate,
            fileSize: fileSize,
            textEncoding: detectedEncoding
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
    private func loadSampleBook() {
        books = [createSampleBook()]
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
            
            // Sort books by import date (newest first)
            books.sort { $0.importedDate > $1.importedDate }
        } else {
            debugPrint("⚠️ LibraryViewModel: Book already exists with same content hash")
        }
    }
    
    /// Refresh the book list by reloading from storage
    func refreshBooks() {
        debugPrint("🔄 LibraryViewModel: Refreshing book list")
        loadBooks()
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
                    // Refresh the entire book list to ensure we have the most up-to-date data
                    self?.refreshBooks()
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