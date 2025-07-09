//
//  AppCoordinator.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI
import Combine

/// AppCoordinator manages the navigation flow and dependency injection for the entire app
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
    
    // MARK: - View State
    enum AppView {
        case library
        case reader
        case settings
        case loading
    }
    
    // MARK: - Services (Lazy Initialization for Performance)
    
    // File processing service for handling text files
    // lazy var fileProcessor = FileProcessor()
    
    // Pagination service for text layout
    lazy var paginationService = PaginationService()
    
    // Speech service for text-to-speech
    // lazy var speechService = SpeechService()
    
    // Persistence service for saving user data
    // lazy var persistenceService = PersistenceService()
    
    // CORE-2: Demonstrating Swift/Objective-C interoperability
    lazy var interoperabilityService = InteroperabilityService()
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Initialize coordinator
        debugPrint("🚀 AppCoordinator: Initializing")
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
    }
    
    // MARK: - Deinit
    
    deinit {
        debugPrint("♻️ AppCoordinator: Deinitializing")
    }
} 