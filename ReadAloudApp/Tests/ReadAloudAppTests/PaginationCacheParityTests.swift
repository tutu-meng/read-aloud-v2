//
//  PaginationCacheParityTests.swift
//  ReadAloudAppTests
//

import XCTest
import Combine
@testable import ReadAloudApp

final class PaginationCacheParityTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    // Print-and-assert helper to compare UI vs cached content
    private func assertEqualAndPrint(_ actual: String, _ expected: String, page: Int, file: StaticString = #filePath, line: UInt = #line) {
        print("[Parity] Page \\(#page): UI displayed=\"\\(actual)\"\n[Parity] Page \\(#page): Cached=\"\\(expected)\"")
        if actual != expected {
            let a = Array(actual)
            let b = Array(expected)
            var firstDiff: Int? = nil
            let maxLen = max(a.count, b.count)
            for i in 0..<maxLen {
                if i >= a.count || i >= b.count || a[i] != b[i] {
                    firstDiff = i
                    break
                }
            }
            if let i = firstDiff {
                let start = max(0, i - 10)
                let endA = min(a.count, i + 10)
                let endB = min(b.count, i + 10)
                let ctxA = String(a[start..<endA])
                let ctxB = String(b[start..<endB])
                print("[Parity] First diff at index \\(#i).\n  UI segment:    \"\\(ctxA)\"\n  Cached segment: \"\\(ctxB)\"")
                print("[Parity] Lengths — UI: \\(a.count), Cached: \\(b.count)")
            }
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testReaderLoadsExactContentFromSavedPaginationCache() {
        // Arrange: fixed settings, view size, and known page contents
        let coordinator = AppCoordinator()
        let persistence = PersistenceService.shared
        let testDefaults = UserDefaults(suiteName: "com.readaloudapp.tests.parity")!
        persistence.overrideUserDefaultsForTesting(testDefaults)
        testDefaults.removePersistentDomain(forName: "com.readaloudapp.tests.parity")

        let book = Book(
            title: "Parity Test Book",
            fileURL: URL(fileURLWithPath: "/tmp/parity.txt"),
            contentHash: "parity-hash-123",
            importedDate: Date(),
            fileSize: 100
        )

        // Ensure background uses the same drawable size keying as the reader
        let containerSize = CGSize(width: 300, height: 500)
        let viewSize = LayoutMetrics.computeTextDrawableSize(container: containerSize)
        persistence.saveLastViewSize(viewSize)

        // Use current settings for cache key
        let settings = coordinator.userSettings
        let settingsKey = PaginationCache.cacheKey(bookHash: book.contentHash, settings: settings, viewSize: viewSize)

        // Create a cache with deterministic contents
        let page0 = PaginationCache.Page(index: 0, rangeLocation: 0, rangeLength: 21, content: "Hello world page 1 ✅")
        let page1 = PaginationCache.Page(index: 1, rangeLocation: 21, rangeLength: 21, content: "Hello world page 2 ✅")
        let page2 = PaginationCache.Page(index: 2, rangeLocation: 42, rangeLength: 21, content: "Hello world page 3 ✅")
        let cache = PaginationCache(
            bookHash: book.contentHash,
            settingsKey: settingsKey,
            createdAt: Date(),
            isComplete: true,
            totalPages: 3,
            pages: [page0, page1, page2]
        )

        // Save cache to disk
        XCTAssertNoThrow(try persistence.savePaginationCache(cache))

        // Act: create reader and wait for it to load from cache
        let viewModel = ReaderViewModel(book: book, coordinator: coordinator)
        viewModel.updateViewSize(viewSize)

        let exp = expectation(description: "Reader loaded page 0 from cache")
        viewModel.$pageContent
            .dropFirst()
            .sink { content in
                if content == page0.content {
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [exp], timeout: 2.0)

        // Assert: exact match for current page content and page count
        assertEqualAndPrint(viewModel.pageContent, page0.content, page: 1)
        XCTAssertEqual(viewModel.totalPages, 3)

        // And switching pages reads exact persisted content
        viewModel.goToPage(2)
        assertEqualAndPrint(viewModel.pageContent, page2.content, page: 3)
    }

    func testUIContentMatchesPaginationCacheForSeveralPages() {
        // Arrange
        let coordinator = AppCoordinator()
        let persistence = PersistenceService.shared
        let testDefaults = UserDefaults(suiteName: "com.readaloudapp.tests.parity2")!
        persistence.overrideUserDefaultsForTesting(testDefaults)
        testDefaults.removePersistentDomain(forName: "com.readaloudapp.tests.parity2")

        let book = Book(
            title: "Parity Test Book 2",
            fileURL: URL(fileURLWithPath: "/tmp/parity2.txt"),
            contentHash: "parity-hash-456",
            importedDate: Date(),
            fileSize: 100
        )

        let containerSize = CGSize(width: 320, height: 560)
        let viewSize = LayoutMetrics.computeTextDrawableSize(container: containerSize)
        persistence.saveLastViewSize(viewSize)
        let settings = coordinator.userSettings
        let settingsKey = PaginationCache.cacheKey(bookHash: book.contentHash, settings: settings, viewSize: viewSize)

        // Three deterministic pages
        let p0 = PaginationCache.Page(index: 0, rangeLocation: 0, rangeLength: 12, content: "Page0 contents")
        let p1 = PaginationCache.Page(index: 1, rangeLocation: 12, rangeLength: 12, content: "Page1 contents")
        let p2 = PaginationCache.Page(index: 2, rangeLocation: 24, rangeLength: 12, content: "Page2 contents")
        let cache = PaginationCache(
            bookHash: book.contentHash,
            settingsKey: settingsKey,
            createdAt: Date(),
            isComplete: true,
            totalPages: 3,
            pages: [p0, p1, p2]
        )

        XCTAssertNoThrow(try persistence.savePaginationCache(cache))

        // Act
        let vm = ReaderViewModel(book: book, coordinator: coordinator)
        vm.updateViewSize(viewSize)

        // Assert page 1 equals cache
        let exp1 = expectation(description: "First page parity")
        vm.$pageContent.dropFirst().sink { content in
            if content == p0.content { exp1.fulfill() }
        }.store(in: &cancellables)
        wait(for: [exp1], timeout: 2.0)
        assertEqualAndPrint(vm.pageContent, p0.content, page: 1)

        // Go to page 2 and 3 and compare
        vm.goToPage(1)
        assertEqualAndPrint(vm.pageContent, p1.content, page: 2)
        vm.goToPage(2)
        assertEqualAndPrint(vm.pageContent, p2.content, page: 3)
    }

    func testUnicodeBoundaryNoLossAcrossConcatenatedPages() {
        // Arrange a cache with unicode characters near page boundaries
        let coordinator = AppCoordinator()
        let persistence = PersistenceService.shared
        let testDefaults = UserDefaults(suiteName: "com.readaloudapp.tests.parity3")!
        persistence.overrideUserDefaultsForTesting(testDefaults)
        testDefaults.removePersistentDomain(forName: "com.readaloudapp.tests.parity3")

        let book = Book(
            title: "Unicode Parity",
            fileURL: URL(fileURLWithPath: "/tmp/unicode.txt"),
            contentHash: "unicode-hash-789",
            importedDate: Date(),
            fileSize: 100
        )

        let containerSize = CGSize(width: 320, height: 560)
        let viewSize = LayoutMetrics.computeTextDrawableSize(container: containerSize)
        persistence.saveLastViewSize(viewSize)
        let settings = coordinator.userSettings
        let settingsKey = PaginationCache.cacheKey(bookHash: book.contentHash, settings: settings, viewSize: viewSize)

        // Construct two pages where the split may fall in multi-byte sequences
        let part1 = "这是第一部分🙂END"
        let part2 = "开始第二部分🚀OK"
        let p0 = PaginationCache.Page(index: 0, rangeLocation: 0, rangeLength: (part1 as NSString).length, content: part1)
        let p1 = PaginationCache.Page(index: 1, rangeLocation: (part1 as NSString).length, rangeLength: (part2 as NSString).length, content: part2)
        let cache = PaginationCache(
            bookHash: book.contentHash,
            settingsKey: settingsKey,
            createdAt: Date(),
            isComplete: true,
            totalPages: 2,
            pages: [p0, p1]
        )

        XCTAssertNoThrow(try persistence.savePaginationCache(cache))

        // Act: load via reader and concatenate
        let vm = ReaderViewModel(book: book, coordinator: coordinator)
        vm.updateViewSize(viewSize)

        // Wait first
        let exp1 = expectation(description: "Loaded first page")
        vm.$pageContent.dropFirst().sink { content in
            if content == part1 { exp1.fulfill() }
        }.store(in: &cancellables)
        wait(for: [exp1], timeout: 2.0)

        let uiFirst = vm.pageContent
        vm.goToPage(1)
        let uiSecond = vm.pageContent

        // Assert concatenation equals original pieces joined
        XCTAssertEqual(uiFirst + uiSecond, part1 + part2)
    }
}


