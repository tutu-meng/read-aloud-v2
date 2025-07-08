//
//  UIWorkflowTests.swift
//  ReadAloudAppTests
//
//  Tests demonstrating the UI workflow with sample text file
//

import XCTest
import Combine
@testable import ReadAloudApp

final class UIWorkflowTests: XCTestCase {
    
    var coordinator: AppCoordinator!
    var libraryViewModel: LibraryViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
        libraryViewModel = coordinator.makeLibraryViewModel()
        cancellables = []
    }
    
    override func tearDown() {
        coordinator = nil
        libraryViewModel = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Workflow Tests
    
    func testCompleteUIWorkflow() {
        // Step 1: Start the app
        coordinator.start()
        XCTAssertEqual(coordinator.currentView, .library, "App should start at library view")
        
        // Step 2: Library should have sample book
        let expectation = XCTestExpectation(description: "Books loaded")
        
        libraryViewModel.$books
            .dropFirst() // Skip initial empty state
            .sink { books in
                if !books.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(libraryViewModel.books.count, 1, "Should have one sample book")
        let sampleBook = libraryViewModel.books[0]
        XCTAssertEqual(sampleBook.title, "Alice's Adventures in Wonderland")
        
        // Step 3: Select book to navigate to reader
        libraryViewModel.selectBook(sampleBook)
        XCTAssertEqual(coordinator.currentView, .reader, "Should navigate to reader view")
        XCTAssertNotNil(coordinator.selectedBook, "Selected book should be set")
        XCTAssertEqual(coordinator.selectedBook?.title, "Alice's Adventures in Wonderland")
        
        // Step 4: Reader should load book content
        let readerViewModel = coordinator.makeReaderViewModel(for: sampleBook)
        
        let loadingExpectation = XCTestExpectation(description: "Book content loaded")
        
        readerViewModel.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading {
                    loadingExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [loadingExpectation], timeout: 3.0)
        
        XCTAssertFalse(readerViewModel.isLoading, "Book should be loaded")
        XCTAssertGreaterThan(readerViewModel.totalPages, 0, "Should have pages")
        XCTAssertFalse(readerViewModel.pageContent.isEmpty, "Should have content")
        
        // Step 5: Test page navigation
        let initialPage = readerViewModel.currentPage
        XCTAssertEqual(initialPage, 0, "Should start at first page")
        
        // Navigate to page 2
        if readerViewModel.totalPages > 1 {
            readerViewModel.goToPage(1)
            XCTAssertEqual(readerViewModel.currentPage, 1, "Should navigate to page 2")
            
            // Content should update when page changes
            let contentExpectation = XCTestExpectation(description: "Page content updated")
            
            readerViewModel.$pageContent
                .dropFirst()
                .sink { content in
                    if !content.isEmpty {
                        contentExpectation.fulfill()
                    }
                }
                .store(in: &cancellables)
            
            wait(for: [contentExpectation], timeout: 1.0)
        }
        
        // Step 6: Test navigation back to library
        readerViewModel.goBackToLibrary()
        XCTAssertEqual(coordinator.currentView, .library, "Should navigate back to library")
    }
    
    func testSampleBookContentLoading() {
        // Test that actual file content is loaded
        let sampleBook = Book(
            title: "Alice's Adventures in Wonderland",
            fileURL: URL(fileURLWithPath: "Resources/SampleBooks/alice_in_wonderland.txt"),
            contentHash: "sample-alice-hash",
            importedDate: Date(),
            fileSize: 5102
        )
        
        let readerViewModel = coordinator.makeReaderViewModel(for: sampleBook)
        
        let expectation = XCTestExpectation(description: "Content loaded")
        
        readerViewModel.$pageContent
            .dropFirst()
            .sink { content in
                if content.contains("ALICE'S ADVENTURES") || content.contains("Down the Rabbit-Hole") {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 3.0)
        
        // Verify we're loading actual book content
        let content = readerViewModel.pageContent
        XCTAssertTrue(
            content.contains("Alice") || content.contains("ALICE"),
            "Should contain content from Alice in Wonderland"
        )
    }
} 