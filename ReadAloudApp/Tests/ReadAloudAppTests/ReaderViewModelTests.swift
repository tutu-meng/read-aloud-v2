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
    
    func testLoadBookSetsMultiplePages() {
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
    
    func testInitialPageContentContainsPageNumber() {
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
        XCTAssertTrue(viewModel.pageContent.contains("Page 1"), "Content should indicate page 1")
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
    
    func testGoToPageValidatesPageBounds() {
        // Given
        viewModel.loadBook()
        let expectation = XCTestExpectation(description: "Book loads")
        
        viewModel.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
        
        // When/Then - Valid page
        viewModel.goToPage(5)
        XCTAssertEqual(viewModel.currentPage, 5)
        
        // When/Then - Invalid negative page
        viewModel.goToPage(-1)
        XCTAssertEqual(viewModel.currentPage, 5, "Should not change to invalid page")
        
        // When/Then - Invalid page beyond total
        viewModel.goToPage(15)
        XCTAssertEqual(viewModel.currentPage, 5, "Should not change to invalid page")
    }
    
    // MARK: - Speech Toggle Tests
    
    func testToggleSpeech() {
        // Given
        XCTAssertFalse(viewModel.isSpeaking)
        
        // When
        viewModel.toggleSpeech()
        
        // Then
        XCTAssertTrue(viewModel.isSpeaking)
        
        // When
        viewModel.toggleSpeech()
        
        // Then
        XCTAssertFalse(viewModel.isSpeaking)
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
        viewModel.goBackToLibrary()
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(coordinator.currentView, .library)
    }
    
    // MARK: - Page Content Tests
    
    func testPageContentFormat() {
        // Given
        let expectation = XCTestExpectation(description: "Page content is formatted correctly")
        
        viewModel.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.loadBook()
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        
        let content = viewModel.pageContent
        XCTAssertTrue(content.contains("Page 1 of Test Book"))
        XCTAssertTrue(content.contains("placeholder content"))
        XCTAssertTrue(content.contains("Lorem ipsum"))
    }
} 