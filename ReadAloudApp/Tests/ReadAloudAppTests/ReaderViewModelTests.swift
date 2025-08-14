//
//  ReaderViewModelTests.swift
//  ReadAloudAppTests
//
//  Tests for UI-1: ReaderViewModel page navigation functionality
//

import XCTest
import Combine
@testable import ReadAloudApp

final class ReaderViewModelTests: XCTestCase {
    
    var coordinator: AppCoordinator!
    var viewModel: ReaderViewModel!
    var cancellables: Set<AnyCancellable>!
    var testBook: Book!
    
    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
        testBook = Book(
            title: "Test Book",
            fileURL: URL(fileURLWithPath: "/test/book.txt"),
            contentHash: "test-hash",
            importedDate: Date(),
            fileSize: 1000
        )
        viewModel = ReaderViewModel(book: testBook, coordinator: coordinator)
        cancellables = []
    }
    
    override func tearDown() {
        viewModel = nil
        coordinator = nil
        testBook = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testReaderViewModelInitialization() {
        XCTAssertEqual(viewModel.book.title, "Test Book")
        XCTAssertEqual(viewModel.currentPage, 0)
        XCTAssertEqual(viewModel.totalPages, 0)
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertFalse(viewModel.isSpeaking)
    }
    
    // MARK: - Page Loading Tests
    
    func disabled_testLoadBookSetsMultiplePages() {
        // Given
        let expectation = XCTestExpectation(description: "Book loads with multiple pages")
        
        // When
        viewModel.$isLoading
            .dropFirst() // Skip initial value
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(viewModel.totalPages, 10, "Should simulate 10 pages for testing")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.pageContent.isEmpty, "Page content should not be empty")
    }
    
    func disabled_testInitialPageContentContainsPageNumber() {
        // Given
        let expectation = XCTestExpectation(description: "Initial page content is set")
        
        // When
        viewModel.$pageContent
            .dropFirst() // Skip initial empty value
            .sink { content in
                if !content.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(viewModel.pageContent.contains("Loading"), "Should show loading state initially")
        XCTAssertTrue(viewModel.pageContent.contains(testBook.title), "Content should contain book title")
    }
    
    // MARK: - Page Navigation Tests
    
    func testCurrentPageUpdatesTriggerContentUpdate() {
        // Given
        let expectation = XCTestExpectation(description: "Page content updates when page changes")
        viewModel.loadBook()
        
        // Wait for initial load
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // When
            self.viewModel.currentPage = 3
            
            // Then
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertTrue(self.viewModel.pageContent.contains("Page 4"), "Content should indicate page 4 (0-indexed)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    
    
    // MARK: - Speech Toggle Tests
    
    func testToggleSpeech() {
        // Given
        XCTAssertFalse(viewModel.isSpeaking)
        // Ensure language set to avoid first-time picker
        var settings = coordinator.userSettings
        settings.speechLanguageCode = "en-US"
        coordinator.saveUserSettings(settings)

        // When
        viewModel.toggleSpeech()

        // Then
        XCTAssertTrue(viewModel.isSpeaking)

        // When
        viewModel.toggleSpeech()

        // Then
        XCTAssertFalse(viewModel.isSpeaking)
    }

    func testTTSPickerShownFirstTimeAndConfirmSelectionStartsSpeech() {
        // Given: ensure no language is set (clear any persisted value)
        coordinator.saveUserSettings(UserSettings())
        XCTAssertNil(coordinator.userSettings.speechLanguageCode)
        XCTAssertFalse(viewModel.isSpeaking)

        // When: first toggle should prompt picker instead of starting speech
        viewModel.toggleSpeech()

        // Then
        XCTAssertTrue(viewModel.shouldPresentTTSPicker)
        XCTAssertFalse(viewModel.isSpeaking)

        // When: confirm selection
        viewModel.confirmTTSLanguageSelection(code: "en-US")

        // Then: language saved and speech started
        XCTAssertEqual(coordinator.userSettings.speechLanguageCode, "en-US")
        XCTAssertTrue(viewModel.isSpeaking)
        XCTAssertFalse(viewModel.shouldPresentTTSPicker)
    }
    
    // MARK: - Navigation Tests
    
    func testGoBackToLibrary() {
        // Given
        let expectation = XCTestExpectation(description: "Navigate to library")
        
        coordinator.$currentView
            .dropFirst()
            .sink { view in
                if view == .library {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.closeBook()
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(coordinator.currentView, .library)
    }
    
    // MARK: - Page Content Tests
    
    
} 