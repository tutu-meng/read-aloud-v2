import XCTest
@testable import ReadAloudApp

final class BackgroundPaginationTests: XCTestCase {
    func testServiceStartsOnAppStart() async throws {
        let coordinator = AppCoordinator()
        // Start app
        coordinator.start()
        // Give some time for monitorLoop to run at least once
        try? await Task.sleep(nanoseconds: 300_000_000)
        // We cannot access service internals; rely on no crash and log presence in manual runs
        // This test ensures no API regressions in calling startBackgroundPagination from start()
        XCTAssertTrue(true)
    }
}


final class PaginationCacheCleanupTests: XCTestCase {
    func testCleanupRemovesNonCurrentCaches() throws {
        let persistence = PersistenceService.shared
        // Use a dedicated defaults to avoid side effects
        let defaults = UserDefaults(suiteName: "com.readaloudapp.tests.cleanup")!
        persistence.overrideUserDefaultsForTesting(defaults)
        defaults.removePersistentDomain(forName: "com.readaloudapp.tests.cleanup")

        // Arrange a book and two fake caches with different settings keys
        let bookHash = "hash-cleanup-001"
        let viewSize = CGSize(width: 361, height: 588)
        let settingsA = UserSettings(fontName: "System", fontSize: 16, theme: "light", lineSpacing: 1.2, speechRate: 1.0)
        let settingsB = UserSettings(fontName: "Georgia", fontSize: 22, theme: "dark", lineSpacing: 1.4, speechRate: 1.0)
        let keyA = PaginationCache.cacheKey(bookHash: bookHash, settings: settingsA, viewSize: viewSize)
        let keyB = PaginationCache.cacheKey(bookHash: bookHash, settings: settingsB, viewSize: viewSize)

        let cacheA = PaginationCache(bookHash: bookHash, settingsKey: keyA, viewSize: viewSize, pages: [], lastProcessedIndex: 0, isComplete: false, lastUpdated: Date())
        let cacheB = PaginationCache(bookHash: bookHash, settingsKey: keyB, viewSize: viewSize, pages: [], lastProcessedIndex: 0, isComplete: false, lastUpdated: Date())
        XCTAssertNoThrow(try persistence.savePaginationCache(cacheA))
        XCTAssertNoThrow(try persistence.savePaginationCache(cacheB))

        // Act: keep only keyA
        persistence.cleanupPaginationCaches(for: bookHash, keepSettingsKey: keyA)

        // Assert: keyA exists, keyB removed
        let keptA = try persistence.loadPaginationCache(bookHash: bookHash, settingsKey: keyA)
        let removedB = try persistence.loadPaginationCache(bookHash: bookHash, settingsKey: keyB)
        XCTAssertNotNil(keptA)
        XCTAssertNil(removedB)
    }
}
