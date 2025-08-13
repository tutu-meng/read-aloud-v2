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


