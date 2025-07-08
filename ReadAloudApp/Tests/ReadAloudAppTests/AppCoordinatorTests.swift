//
//  AppCoordinatorTests.swift
//  ReadAloudAppTests
//
//  Created on 2024
//

import XCTest
import Combine
@testable import ReadAloudApp

final class AppCoordinatorTests: XCTestCase {
    
    var coordinator: AppCoordinator!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        coordinator = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - CORE-4 Requirements Tests
    
    func testAppCoordinatorInitialization() {
        // Test that AppCoordinator initializes properly
        XCTAssertNotNil(coordinator)
        XCTAssertEqual(coordinator.currentView, .library)
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.errorMessage)
    }
    
    func testStartMethod() {
        // Test that start() method sets up initial state
        coordinator.start()
        
        XCTAssertEqual(coordinator.currentView, .library)
        XCTAssertNil(coordinator.selectedBook)
    }
    
    func testNavigationToReader() {
        // Test navigation to reader
        let book = Book(
            id: UUID(),
            title: "Test Book",
            fileURL: URL(fileURLWithPath: "/test/path"),
            contentHash: "test-hash-123",
            importedDate: Date(),
            fileSize: 1000
        )
        
        coordinator.navigateToReader(with: book)
        
        XCTAssertEqual(coordinator.currentView, .reader)
        XCTAssertEqual(coordinator.selectedBook?.id, book.id)
    }
    
    func testNavigationToLibrary() {
        // Setup: Navigate to reader first
        let book = Book(
            id: UUID(),
            title: "Test Book",
            fileURL: URL(fileURLWithPath: "/test/path"),
            contentHash: "test-hash-123",
            importedDate: Date(),
            fileSize: 1000
        )
        coordinator.navigateToReader(with: book)
        
        // Test navigation back to library
        coordinator.navigateToLibrary()
        
        XCTAssertEqual(coordinator.currentView, .library)
        XCTAssertNil(coordinator.selectedBook)
    }
    
    func testNavigationToSettings() {
        // Test navigation to settings
        coordinator.showSettings()
        
        XCTAssertEqual(coordinator.currentView, .settings)
    }
    
    func testViewModelFactoryMethods() {
        // Test LibraryViewModel creation
        let libraryVM = coordinator.makeLibraryViewModel()
        XCTAssertNotNil(libraryVM)
        // Note: coordinator property is private, so we can't test direct reference
        
        // Test ReaderViewModel creation
        let book = Book(
            id: UUID(),
            title: "Test Book",
            fileURL: URL(fileURLWithPath: "/test/path"),
            contentHash: "test-hash-123",
            importedDate: Date(),
            fileSize: 1000
        )
        let readerVM = coordinator.makeReaderViewModel(for: book)
        XCTAssertNotNil(readerVM)
        XCTAssertEqual(readerVM.book.id, book.id)
        
        // Test SettingsViewModel creation
        let settingsVM = coordinator.makeSettingsViewModel()
        XCTAssertNotNil(settingsVM)
    }
    
    func testErrorHandling() {
        // Test error handling
        let testError = NSError(domain: "TestError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error message"])
        
        coordinator.handleError(testError)
        
        XCTAssertEqual(coordinator.errorMessage, "Test error message")
        
        // Test error clearing
        coordinator.clearError()
        XCTAssertNil(coordinator.errorMessage)
    }
    
    func testErrorAutoClear() {
        // Test that error message clears automatically after delay
        let expectation = XCTestExpectation(description: "Error should clear after delay")
        let testError = NSError(domain: "TestError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        coordinator.handleError(testError)
        XCTAssertNotNil(coordinator.errorMessage)
        
        // Wait for auto-clear (5 seconds + buffer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { [weak self] in
            XCTAssertNil(self?.coordinator.errorMessage)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 7.0)
    }
    
    func testDeepLinkHandling() {
        // Test deep link handler exists (implementation is TODO)
        let testURL = URL(string: "readAloud://open/book/123")!
        
        // This should not crash
        coordinator.handleDeepLink(testURL)
    }
    
    func testLoadingState() {
        // Test loading state can be set
        coordinator.isLoading = true
        XCTAssertTrue(coordinator.isLoading)
        
        coordinator.isLoading = false
        XCTAssertFalse(coordinator.isLoading)
    }
    
    func testInteroperabilityServiceInitialization() {
        // Test that interoperability service is lazily initialized
        let service = coordinator.interoperabilityService
        XCTAssertNotNil(service)
        
        // Accessing again should return the same instance
        let sameService = coordinator.interoperabilityService
        XCTAssertTrue(service === sameService)
    }
} 