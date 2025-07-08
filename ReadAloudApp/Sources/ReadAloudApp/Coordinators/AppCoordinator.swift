//
//  AppCoordinator.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI
import Combine

/// AppCoordinator manages the navigation flow and dependency injection for the entire app
class AppCoordinator: ObservableObject {
    
    // MARK: - Navigation State
    @Published var currentView: AppView = .library
    @Published var selectedBook: Book?
    
    // MARK: - View State
    enum AppView {
        case library
        case reader
        case settings
    }
    
    // MARK: - Services (will be initialized as needed)
    // lazy var fileProcessor = FileProcessor()
    // lazy var paginationService = PaginationService()
    // lazy var speechService = SpeechService()
    // lazy var persistenceService = PersistenceService()
    
    // CORE-2: Demonstrating Swift/Objective-C interoperability
    lazy var interoperabilityService = InteroperabilityService()
    
    // MARK: - Navigation Methods
    
    /// Navigate to the reader view with a selected book
    func navigateToReader(with book: Book) {
        selectedBook = book
        currentView = .reader
    }
    
    /// Navigate back to the library
    func navigateToLibrary() {
        currentView = .library
        selectedBook = nil
    }
    
    /// Show settings
    func showSettings() {
        currentView = .settings
    }
    
    // MARK: - ViewModels Factory Methods
    
    /// Create LibraryViewModel with dependencies
    func makeLibraryViewModel() -> LibraryViewModel {
        return LibraryViewModel(coordinator: self)
    }
    
    /// Create ReaderViewModel with dependencies
    func makeReaderViewModel(for book: Book) -> ReaderViewModel {
        return ReaderViewModel(book: book, coordinator: self)
    }
    
    /// Create SettingsViewModel with dependencies
    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(coordinator: self)
    }
} 