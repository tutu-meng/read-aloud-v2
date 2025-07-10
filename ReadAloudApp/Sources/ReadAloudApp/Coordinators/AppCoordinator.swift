//
//  AppCoordinator.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI
import Combine

// MARK: - Notification Names
extension Notification.Name {
    static let bookAdded = Notification.Name("bookAdded")
}

/// AppCoordinator manages the overall application flow and dependencies
/// This is the "Coordinator" in the MVVM-C pattern, responsible for:
/// - Managing navigation state
/// - Creating and injecting dependencies
/// - Coordinating between different parts of the app
class AppCoordinator: ObservableObject {
    
    // MARK: - Navigation State
    @Published var currentView: AppView = .library
    @Published var selectedBook: Book?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Shared Settings State
    @Published var userSettings: UserSettings = .default
    
    // MARK: - Reading Progress State
    @Published var readingProgressList: [ReadingProgress] = []
    
    // MARK: - View State
    enum AppView {
        case library
        case reader
        case settings
        case loading
    }
    
    // MARK: - Services (Lazy Initialization for Performance)
    
    // File processing service for handling text files
    lazy var fileProcessor = FileProcessor()
    
    // CORE-2: Demonstrating Swift/Objective-C interoperability
    lazy var interoperabilityService = InteroperabilityService()
    
    // Persistence service for state management
    private let persistenceService = PersistenceService.shared
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Initialize coordinator
        debugPrint("🚀 AppCoordinator: Initializing")
        
        // Load initial settings and data
        loadInitialSettings()
    }
    
    // MARK: - Start Method (CORE-4 Requirement)
    
    /// Start the coordinator and set up the initial state
    /// This method initializes the app's navigation flow
    func start() {
        debugPrint("🎬 AppCoordinator: Starting application")
        
        // Set initial state
        currentView = .library
        selectedBook = nil
        
        // Setup any initial observers or subscriptions
        setupObservers()
        
        // Load any initial data
        loadInitialData()
    }
    
    // MARK: - Navigation Methods
    
    /// Navigate to the reader view with a selected book
    func navigateToReader(with book: Book) {
        debugPrint("📖 AppCoordinator: Navigating to reader with book: \(book.title)")
        selectedBook = book
        currentView = .reader
    }
    
    /// Navigate back to the library
    func navigateToLibrary() {
        debugPrint("📚 AppCoordinator: Navigating to library")
        currentView = .library
        selectedBook = nil
    }
    
    /// Show settings
    func showSettings() {
        debugPrint("⚙️ AppCoordinator: Showing settings")
        currentView = .settings
    }
    
    /// Handle navigation from deep links or external sources
    func handleDeepLink(_ url: URL) {
        debugPrint("🔗 AppCoordinator: Handling deep link: \(url)")
        // TODO: Implement deep link handling
    }
    
    // MARK: - Service Factory Methods
    
    /// Create PaginationService with required dependencies
    /// - Parameters:
    ///   - textSource: The TextSource for pagination
    ///   - userSettings: Optional user settings (defaults to coordinator's settings)
    /// - Returns: Configured PaginationService instance
    func makePaginationService(textSource: TextSource, userSettings: UserSettings? = nil) -> PaginationService {
        let settings = userSettings ?? self.userSettings
        debugPrint("🏭 AppCoordinator: Creating PaginationService with TextSource and UserSettings")
        return PaginationService(textSource: textSource, userSettings: settings)
    }
    
    /// Create PaginationService with pre-extracted text content (encoding-aware)
    /// - Parameters:
    ///   - textContent: The pre-extracted text content with correct encoding
    ///   - userSettings: Optional user settings (defaults to coordinator's settings)
    /// - Returns: Configured PaginationService instance
    func makePaginationService(textContent: String, userSettings: UserSettings? = nil) -> PaginationService {
        let settings = userSettings ?? self.userSettings
        debugPrint("🏭 AppCoordinator: Creating PaginationService with pre-extracted text content (\(textContent.count) chars)")
        return PaginationService(textContent: textContent, userSettings: settings)
    }
    
    // MARK: - ViewModels Factory Methods (Dependency Injection)
    
    /// Create LibraryViewModel with dependencies
    func makeLibraryViewModel() -> LibraryViewModel {
        debugPrint("🏭 AppCoordinator: Creating LibraryViewModel")
        return LibraryViewModel(coordinator: self)
    }
    
    /// Create ReaderViewModel with dependencies
    func makeReaderViewModel(for book: Book) -> ReaderViewModel {
        debugPrint("🏭 AppCoordinator: Creating ReaderViewModel for book: \(book.title)")
        return ReaderViewModel(book: book, coordinator: self)
    }
    
    /// Create SettingsViewModel with dependencies
    func makeSettingsViewModel() -> SettingsViewModel {
        debugPrint("🏭 AppCoordinator: Creating SettingsViewModel")
        return SettingsViewModel(coordinator: self)
    }
    
    // MARK: - File Import Handling
    
    /// Handle file import from document picker
    /// - Parameter fileURL: The URL of the selected text file
    func handleFileImport(_ fileURL: URL) {
        debugPrint("📥 AppCoordinator: Handling file import: \(fileURL.lastPathComponent)")
        
        // Start loading state
        isLoading = true
        
        Task {
            do {
                // Start accessing the security-scoped resource
                guard fileURL.startAccessingSecurityScopedResource() else {
                    throw AppError.fileAccessDenied
                }
                
                defer {
                    // Stop accessing the security-scoped resource
                    fileURL.stopAccessingSecurityScopedResource()
                }
                
                // Process the imported file using FileProcessor
                let fileProcessor = FileProcessor()
                let book = try await fileProcessor.processImportedFile(from: fileURL)
                
                // Add the book to the library
                await addBookToLibrary(book)
                
                await MainActor.run {
                    self.isLoading = false
                    debugPrint("✅ AppCoordinator: File import completed successfully")
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.handleError(error)
                }
            }
        }
    }
    
    /// Add a book to the library and notify observers
    /// - Parameter book: The book to add
    @MainActor
    private func addBookToLibrary(_ book: Book) async {
        debugPrint("📚 AppCoordinator: Adding book to library: \(book.title)")
        
        // TODO: This will be enhanced when we implement persistent storage
        // For now, we'll use a simple in-memory approach
        
        // Notify the LibraryViewModel to add the book
        // This is a temporary solution until we implement proper persistence
        NotificationCenter.default.post(
            name: .bookAdded,
            object: nil,
            userInfo: ["book": book]
        )
    }
    
    // MARK: - Error Handling
    
    /// Handle application-wide errors
    func handleError(_ error: Error) {
        // Convert to AppError if needed
        let appError: AppError = (error as? AppError) ?? .unknown(underlyingError: error)
        
        debugPrint("❌ AppCoordinator: Error occurred: [\(appError.errorCode)] \(appError.localizedDescription)")
        errorMessage = appError.localizedDescription
        
        // Clear error after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.errorMessage = nil
        }
    }
    
    /// Clear any error messages
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Persistence Methods
    
    /// Load initial settings and data from persistence
    private func loadInitialSettings() {
        debugPrint("📊 AppCoordinator: Loading initial settings from persistence")
        
        Task {
            do {
                // Load UserSettings from persistence
                let settings = try persistenceService.loadUserSettings()
                
                // Load ReadingProgress from persistence
                let progressList = try persistenceService.loadReadingProgress()
                
                await MainActor.run {
                    self.userSettings = settings
                    self.readingProgressList = progressList
                    debugPrint("✅ AppCoordinator: Loaded settings and \(progressList.count) reading progress entries")
                }
                
            } catch {
                await MainActor.run {
                    debugPrint("⚠️ AppCoordinator: Failed to load settings, using defaults: \(error)")
                    // userSettings and readingProgressList already have default values
                }
            }
        }
    }
    
    /// Save UserSettings to persistence
    /// - Parameter settings: The UserSettings to save
    func saveUserSettings(_ settings: UserSettings) {
        debugPrint("💾 AppCoordinator: Saving UserSettings to persistence")
        
        Task {
            do {
                try persistenceService.saveUserSettings(settings)
                debugPrint("✅ AppCoordinator: UserSettings saved successfully")
            } catch {
                debugPrint("❌ AppCoordinator: Failed to save UserSettings: \(error)")
                await MainActor.run {
                    self.handleError(error)
                }
            }
        }
    }
    
    /// Save ReadingProgress to persistence
    /// - Parameter progress: The ReadingProgress to save or update
    func saveReadingProgress(_ progress: ReadingProgress) {
        debugPrint("💾 AppCoordinator: Saving ReadingProgress for book: \(progress.bookID)")
        
        Task {
            do {
                // Update the progress in our list
                await MainActor.run {
                    if let index = self.readingProgressList.firstIndex(where: { $0.bookID == progress.bookID }) {
                        self.readingProgressList[index] = progress
                    } else {
                        self.readingProgressList.append(progress)
                    }
                }
                
                // Save the entire list to persistence
                try persistenceService.saveReadingProgress(readingProgressList)
                debugPrint("✅ AppCoordinator: ReadingProgress saved successfully")
                
            } catch {
                debugPrint("❌ AppCoordinator: Failed to save ReadingProgress: \(error)")
                await MainActor.run {
                    self.handleError(error)
                }
            }
        }
    }
    
    /// Get ReadingProgress for a specific book
    /// - Parameter bookID: The book's content hash
    /// - Returns: ReadingProgress if found, nil otherwise
    func getReadingProgress(for bookID: String) -> ReadingProgress? {
        return readingProgressList.first { $0.bookID == bookID }
    }
    
    // MARK: - Private Methods
    
    /// Set up any observers or subscriptions
    private func setupObservers() {
        // Observe app lifecycle events if needed
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                debugPrint("📱 AppCoordinator: App will enter foreground")
                self?.handleAppForeground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                debugPrint("📱 AppCoordinator: App did enter background")
                self?.handleAppBackground()
            }
            .store(in: &cancellables)
    }
    
    /// Load any initial data needed for the app
    private func loadInitialData() {
        // TODO: Load user settings
        // TODO: Load book library
        // TODO: Restore last reading position
        debugPrint("📊 AppCoordinator: Loading initial data")
    }
    
    /// Handle app entering foreground
    private func handleAppForeground() {
        // Refresh data if needed
    }
    
    /// Handle app entering background
    private func handleAppBackground() {
        // Save any pending data
        debugPrint("📱 AppCoordinator: App entering background, saving current state")
        
        // Save current user settings
        saveUserSettings(userSettings)
        
        // The ReaderViewModel will handle saving its own progress through app lifecycle notifications
    }
    
    // MARK: - Deinit
    
    deinit {
        debugPrint("♻️ AppCoordinator: Deinitializing")
    }
} 