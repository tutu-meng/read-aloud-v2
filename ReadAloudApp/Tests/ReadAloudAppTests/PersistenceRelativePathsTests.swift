import XCTest
@testable import ReadAloudApp

final class PersistenceRelativePathsTests: XCTestCase {
    private var persistence: PersistenceService!
    private var documentsURL: URL!
    private var libraryFileURL: URL!
    private var originalLibraryData: Data?

    override func setUp() async throws {
        try await super.setUp()
        persistence = PersistenceService.shared
        documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let appSupportPath = persistence.getApplicationSupportPath()!
        libraryFileURL = URL(fileURLWithPath: appSupportPath).appendingPathComponent("BookLibrary.json")

        if FileManager.default.fileExists(atPath: libraryFileURL.path) {
            originalLibraryData = try? Data(contentsOf: libraryFileURL)
        } else {
            originalLibraryData = nil
        }
    }

    override func tearDown() async throws {
        // Restore previous BookLibrary.json
        if let data = originalLibraryData {
            try? data.write(to: libraryFileURL)
        } else {
            try? FileManager.default.removeItem(at: libraryFileURL)
        }
        try await super.tearDown()
    }

    func testSaveAndLoad_UsesRelativePath() throws {
        // Arrange: create a file in Documents
        let filename = "unit-relative.txt"
        let fileURL = documentsURL.appendingPathComponent(filename)
        let sample = "Hello, Library!".data(using: .utf8)!
        FileManager.default.createFile(atPath: fileURL.path, contents: sample)

        let book = Book(
            id: UUID(),
            title: "unit",
            fileURL: fileURL,
            contentHash: "relhash",
            importedDate: Date(),
            fileSize: Int64(sample.count),
            textEncoding: "UTF-8"
        )

        // Act: save then read raw JSON
        try persistence.saveBookLibrary([book])
        let raw = try String(contentsOf: libraryFileURL, encoding: .utf8)

        // Assert JSON contains relativePath and not absolute Documents path
        XCTAssertTrue(raw.contains("\"relativePath\""))
        XCTAssertTrue(raw.contains(filename))
        XCTAssertFalse(raw.contains(documentsURL.path))

        // Act: load back as Book models
        let loaded = try persistence.loadBookLibrary()

        // Assert reconstructed absolute URL and fields
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "unit")
        XCTAssertEqual(loaded[0].fileURL.path, fileURL.path)
        XCTAssertEqual(loaded[0].textEncoding, "UTF-8")
    }

    func testCreateBook_CopyBehavior() async throws {
        let fp = FileProcessor()

        // Case 1: source outside Documents should be copied into Documents
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("unit-outside.txt")
        let data = "ABC".data(using: .utf8)!
        FileManager.default.createFile(atPath: tmpURL.path, contents: data)

        let book1 = try await fp.createBook(from: tmpURL, encoding: "UTF-8")
        XCTAssertTrue(book1.fileURL.path.hasPrefix(documentsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: book1.fileURL.path))

        // Case 2: source already in Documents should not be copied
        let docsSrc = documentsURL.appendingPathComponent("unit-inside.txt")
        FileManager.default.createFile(atPath: docsSrc.path, contents: data)

        let book2 = try await fp.createBook(from: docsSrc, encoding: "UTF-8")
        XCTAssertEqual(book2.fileURL.path, docsSrc.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: book2.fileURL.path))

        // Cleanup created files
        try? FileManager.default.removeItem(at: book1.fileURL)
        try? FileManager.default.removeItem(at: docsSrc)
    }
}


