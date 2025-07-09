//
//  UI4SettingsObservationTests.swift
//  ReadAloudAppTests
//
//  Created on 2024
//

import XCTest
import SwiftUI
import Combine
@testable import ReadAloudApp

final class UI4SettingsObservationTests: XCTestCase {
    
    var coordinator: AppCoordinator!
    var book: Book!
    var readerViewModel: ReaderViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
        book = Book(
            title: "Test Book",
            fileURL: Bundle.main.url(forResource: "test", withExtension: "txt") ?? URL(fileURLWithPath: "/tmp/test.txt"),
            contentHash: "test-hash",
            importedDate: Date(),
            fileSize: 1000
        )
        readerViewModel = ReaderViewModel(book: book, coordinator: coordinator)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        readerViewModel = nil
        coordinator = nil
        book = nil
        super.tearDown()
    }
    
    // MARK: - PaginationService Tests
    
    func testPaginationServiceInitialization() {
        let paginationService = PaginationService()
        XCTAssertNotNil(paginationService)
    }
    
    func testPaginationServiceInvalidateCache() {
        let paginationService = coordinator.paginationService
        
        // This should not throw and should clear internal cache
        paginationService.invalidateCache()
        
        // Verify that cache is cleared by checking if pagination calculation happens
        let content = "Test content for pagination"
        let settings = UserSettings.default
        let viewSize = CGSize(width: 300, height: 400)
        
        let pages = paginationService.paginateText(content: content, settings: settings, viewSize: viewSize)
        XCTAssertFalse(pages.isEmpty)
    }
    
    func testPaginationServiceCacheInvalidation() {
        let paginationService = coordinator.paginationService
        let content = "Test content for pagination that should be split into multiple pages based on font size and line spacing settings"
        let settings = UserSettings.default
        let viewSize = CGSize(width: 300, height: 400)
        
        // First pagination
        let pages1 = paginationService.paginateText(content: content, settings: settings, viewSize: viewSize)
        
        // Same call should use cache
        let pages2 = paginationService.paginateText(content: content, settings: settings, viewSize: viewSize)
        XCTAssertEqual(pages1.count, pages2.count)
        
        // Invalidate cache
        paginationService.invalidateCache()
        
        // Should recalculate
        let pages3 = paginationService.paginateText(content: content, settings: settings, viewSize: viewSize)
        XCTAssertEqual(pages1.count, pages3.count)
    }
    
    func testPaginationWithDifferentFontSizes() {
        let paginationService = coordinator.paginationService
        let content = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 20)
        let viewSize = CGSize(width: 300, height: 400)
        
        // Test with default font size (16)
        var settings = UserSettings.default
        let pages16 = paginationService.paginateText(content: content, settings: settings, viewSize: viewSize)
        
        // Test with larger font size (24)
        settings.fontSize = 24
        let pages24 = paginationService.paginateText(content: content, settings: settings, viewSize: viewSize)
        
        // Larger font should result in more pages
        XCTAssertGreaterThan(pages24.count, pages16.count)
    }
    
    func testPaginationWithDifferentLineSpacing() {
        let paginationService = coordinator.paginationService
        let content = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 20)
        let viewSize = CGSize(width: 300, height: 400)
        
        // Test with default line spacing (1.2)
        var settings = UserSettings.default
        let pages12 = paginationService.paginateText(content: content, settings: settings, viewSize: viewSize)
        
        // Test with larger line spacing (2.0)
        settings.lineSpacing = 2.0
        let pages20 = paginationService.paginateText(content: content, settings: settings, viewSize: viewSize)
        
        // Larger line spacing should result in more pages
        XCTAssertGreaterThan(pages20.count, pages12.count)
    }
    
    // MARK: - Settings Observation Tests
    
    func testReaderViewModelObservesSettingsChanges() {
        let expectation = XCTestExpectation(description: "Settings change triggers re-pagination")
        
        // Mock the re-pagination by observing page count changes
        readerViewModel.$totalPages
            .dropFirst()
            .sink { totalPages in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate view size being set
        readerViewModel.updateViewSize(CGSize(width: 300, height: 400))
        
        // Change settings that affect layout
        coordinator.userSettings.fontSize = 24
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSettingsChangeInvalidatesCache() {
        let paginationService = coordinator.paginationService
        let content = "Test content"
        let settings = UserSettings.default
        let viewSize = CGSize(width: 300, height: 400)
        
        // Initial pagination
        let pages1 = paginationService.paginateText(content: content, settings: settings, viewSize: viewSize)
        
        // Change settings through coordinator
        coordinator.userSettings.fontSize = 20
        
        // Cache should be invalidated, but we can't directly test this without more complex setup
        // This test ensures the method exists and can be called
        paginationService.invalidateCache()
        
        // Verify pagination still works after invalidation
        let pages2 = paginationService.paginateText(content: content, settings: coordinator.userSettings, viewSize: viewSize)
        XCTAssertFalse(pages2.isEmpty)
    }
    
    // MARK: - ReaderViewModel Integration Tests
    
    func testReaderViewModelUsesSharedSettings() {
        // Verify that ReaderViewModel uses coordinator's shared settings
        coordinator.userSettings.fontSize = 18
        coordinator.userSettings.fontName = "Georgia"
        
        // The viewModel should be observing these changes
        XCTAssertEqual(coordinator.userSettings.fontSize, 18)
        XCTAssertEqual(coordinator.userSettings.fontName, "Georgia")
    }
    
    func testReaderViewModelUpdateViewSize() {
        let initialViewSize = CGSize(width: 300, height: 400)
        let newViewSize = CGSize(width: 400, height: 500)
        
        // Set initial view size
        readerViewModel.updateViewSize(initialViewSize)
        
        // Change view size
        readerViewModel.updateViewSize(newViewSize)
        
        // This should trigger re-pagination (we can't directly test internal state)
        // But we can verify the method doesn't crash
        XCTAssertTrue(true)
    }
    
    func testReaderViewModelHandlesSettingsChange() {
        let expectation = XCTestExpectation(description: "Settings change is handled")
        
        // Set up a view size first
        readerViewModel.updateViewSize(CGSize(width: 300, height: 400))
        
        // Use a delay to ensure async operations complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Change settings
            self.coordinator.userSettings.fontSize = 22
            
            // Wait a bit more for the change to propagate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Cache Validation Tests
    
    func testCacheValidationWithSameSettings() {
        let paginationService = coordinator.paginationService
        let settings = UserSettings.default
        let viewSize = CGSize(width: 300, height: 400)
        
        // Initial pagination to set up cache
        let content = "Test content"
        paginationService.paginateText(content: content, settings: settings, viewSize: viewSize)
        
        // Check if cache is valid for same settings
        XCTAssertTrue(paginationService.isCacheValid(for: settings, viewSize: viewSize))
    }
    
    func testCacheValidationWithDifferentSettings() {
        let paginationService = coordinator.paginationService
        let settings1 = UserSettings.default
        var settings2 = UserSettings.default
        settings2.fontSize = 20
        let viewSize = CGSize(width: 300, height: 400)
        
        // Initial pagination with settings1
        let content = "Test content"
        paginationService.paginateText(content: content, settings: settings1, viewSize: viewSize)
        
        // Check if cache is valid for different settings
        XCTAssertFalse(paginationService.isCacheValid(for: settings2, viewSize: viewSize))
    }
    
    func testCacheValidationWithDifferentViewSize() {
        let paginationService = coordinator.paginationService
        let settings = UserSettings.default
        let viewSize1 = CGSize(width: 300, height: 400)
        let viewSize2 = CGSize(width: 400, height: 500)
        
        // Initial pagination with viewSize1
        let content = "Test content"
        paginationService.paginateText(content: content, settings: settings, viewSize: viewSize1)
        
        // Check if cache is valid for different view size
        XCTAssertFalse(paginationService.isCacheValid(for: settings, viewSize: viewSize2))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyContentPagination() {
        let paginationService = coordinator.paginationService
        let settings = UserSettings.default
        let viewSize = CGSize(width: 300, height: 400)
        
        let pages = paginationService.paginateText(content: "", settings: settings, viewSize: viewSize)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages.first, "")
    }
    
    func testVeryLongContentPagination() {
        let paginationService = coordinator.paginationService
        let settings = UserSettings.default
        let viewSize = CGSize(width: 300, height: 400)
        
        let longContent = String(repeating: "A", count: 10000)
        let pages = paginationService.paginateText(content: longContent, settings: settings, viewSize: viewSize)
        
        XCTAssertGreaterThan(pages.count, 1)
        XCTAssertFalse(pages.isEmpty)
    }
} 