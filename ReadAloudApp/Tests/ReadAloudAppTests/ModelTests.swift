//
//  ModelTests.swift
//  ReadAloudAppTests
//
//  Tests for the core data models: Book, UserSettings, and ReadingProgress
//

import XCTest
@testable import ReadAloudApp

final class ModelTests: XCTestCase {
    
    // MARK: - Book Model Tests
    
    func testBookInitialization() {
        let testURL = URL(fileURLWithPath: "/test/path/book.txt")
        let testHash = "abc123hash"
        let testTitle = "Test Book"
        let testSize: Int64 = 1024
        
        let book = Book(
            title: testTitle,
            fileURL: testURL,
            contentHash: testHash,
            fileSize: testSize
        )
        
        XCTAssertEqual(book.title, testTitle)
        XCTAssertEqual(book.fileURL, testURL)
        XCTAssertEqual(book.contentHash, testHash)
        XCTAssertEqual(book.fileSize, testSize)
        XCTAssertNotNil(book.id)
        XCTAssertNotNil(book.importedDate)
    }
    
    func testBookCodable() throws {
        let book = Book(
            title: "Codable Test",
            fileURL: URL(fileURLWithPath: "/test/codable.txt"),
            contentHash: "hash123"
        )
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(book)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedBook = try decoder.decode(Book.self, from: data)
        
        XCTAssertEqual(book.id, decodedBook.id)
        XCTAssertEqual(book.title, decodedBook.title)
        XCTAssertEqual(book.fileURL, decodedBook.fileURL)
        XCTAssertEqual(book.contentHash, decodedBook.contentHash)
    }
    
    func testBookIdentifiable() {
        let book1 = Book(title: "Book 1", fileURL: URL(fileURLWithPath: "/1"), contentHash: "1")
        let book2 = Book(title: "Book 2", fileURL: URL(fileURLWithPath: "/2"), contentHash: "2")
        
        XCTAssertNotEqual(book1.id, book2.id)
    }
    
    // MARK: - UserSettings Model Tests
    
    func testUserSettingsInitialization() {
        let settings = UserSettings(
            fontName: "Georgia",
            fontSize: 18.0,
            theme: "dark",
            lineSpacing: 1.5,
            speechRate: 1.2
        )
        
        XCTAssertEqual(settings.fontName, "Georgia")
        XCTAssertEqual(settings.fontSize, 18.0)
        XCTAssertEqual(settings.theme, "dark")
        XCTAssertEqual(settings.lineSpacing, 1.5)
        XCTAssertEqual(settings.speechRate, 1.2)
    }
    
    func testUserSettingsDefaultValues() {
        let settings = UserSettings()
        
        XCTAssertEqual(settings.fontName, "System")
        XCTAssertEqual(settings.fontSize, 16.0)
        XCTAssertEqual(settings.theme, "light")
        XCTAssertEqual(settings.lineSpacing, 1.2)
        XCTAssertEqual(settings.speechRate, 1.0)
    }
    
    func testUserSettingsCodable() throws {
        let settings = UserSettings(
            fontName: "Helvetica",
            fontSize: 20.0,
            theme: "sepia",
            lineSpacing: 1.8,
            speechRate: 0.8
        )
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedSettings = try decoder.decode(UserSettings.self, from: data)
        
        XCTAssertEqual(settings.fontName, decodedSettings.fontName)
        XCTAssertEqual(settings.fontSize, decodedSettings.fontSize)
        XCTAssertEqual(settings.theme, decodedSettings.theme)
        XCTAssertEqual(settings.lineSpacing, decodedSettings.lineSpacing)
        XCTAssertEqual(settings.speechRate, decodedSettings.speechRate)
    }
    
    func testUserSettingsStaticProperties() {
        XCTAssertEqual(UserSettings.availableThemes, ["light", "dark", "sepia"])
        XCTAssertTrue(UserSettings.availableFonts.contains("System"))
        XCTAssertTrue(UserSettings.availableFonts.contains("Georgia"))
        XCTAssertEqual(UserSettings.fontSizeRange, 12.0...32.0)
        XCTAssertEqual(UserSettings.lineSpacingRange, 0.8...2.0)
        XCTAssertEqual(UserSettings.speechRateRange, 0.5...2.0)
    }
    
    // MARK: - ReadingProgress Model Tests
    
    func testReadingProgressInitialization() {
        let bookID = "book123"
        let charIndex = 12345
        let pageNum = 42
        let totalPages = 100
        let percentage = 0.42
        
        let progress = ReadingProgress(
            bookID: bookID,
            lastReadCharacterIndex: charIndex,
            lastPageNumber: pageNum,
            totalPages: totalPages,
            percentageComplete: percentage
        )
        
        XCTAssertEqual(progress.bookID, bookID)
        XCTAssertEqual(progress.lastReadCharacterIndex, charIndex)
        XCTAssertEqual(progress.lastPageNumber, pageNum)
        XCTAssertEqual(progress.totalPages, totalPages)
        XCTAssertEqual(progress.percentageComplete, percentage)
        XCTAssertNotNil(progress.lastUpdated)
    }
    
    func testReadingProgressCodable() throws {
        let progress = ReadingProgress(
            bookID: "testBook",
            lastReadCharacterIndex: 5000,
            lastPageNumber: 25,
            totalPages: 50,
            percentageComplete: 0.5
        )
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(progress)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedProgress = try decoder.decode(ReadingProgress.self, from: data)
        
        XCTAssertEqual(progress.bookID, decodedProgress.bookID)
        XCTAssertEqual(progress.lastReadCharacterIndex, decodedProgress.lastReadCharacterIndex)
        XCTAssertEqual(progress.lastPageNumber, decodedProgress.lastPageNumber)
        XCTAssertEqual(progress.totalPages, decodedProgress.totalPages)
        XCTAssertEqual(progress.percentageComplete, decodedProgress.percentageComplete)
    }
    
    func testReadingProgressBeginning() {
        let progress = ReadingProgress.beginning(for: "newBook")
        
        XCTAssertEqual(progress.bookID, "newBook")
        XCTAssertEqual(progress.lastReadCharacterIndex, 0)
        XCTAssertEqual(progress.lastPageNumber, 0)
        XCTAssertEqual(progress.percentageComplete, 0.0)
    }
    
    func testReadingProgressUpdatePosition() {
        var progress = ReadingProgress.beginning(for: "book1")
        
        progress.updatePosition(
            characterIndex: 1000,
            pageNumber: 10,
            totalPages: 100
        )
        
        XCTAssertEqual(progress.lastReadCharacterIndex, 1000)
        XCTAssertEqual(progress.lastPageNumber, 10)
        XCTAssertEqual(progress.totalPages, 100)
        XCTAssertEqual(progress.percentageComplete, 0.1)
    }
    
    func testReadingProgressHelpers() {
        // Test hasBeenStarted
        let newProgress = ReadingProgress.beginning(for: "book1")
        XCTAssertFalse(newProgress.hasBeenStarted)
        
        var startedProgress = newProgress
        startedProgress.updatePosition(characterIndex: 1, pageNumber: 1)
        XCTAssertTrue(startedProgress.hasBeenStarted)
        
        // Test isNearlyComplete
        let almostDone = ReadingProgress(
            bookID: "book2",
            lastReadCharacterIndex: 9500,
            percentageComplete: 0.96
        )
        XCTAssertTrue(almostDone.isNearlyComplete)
        
        let notDone = ReadingProgress(
            bookID: "book3",
            lastReadCharacterIndex: 5000,
            percentageComplete: 0.5
        )
        XCTAssertFalse(notDone.isNearlyComplete)
    }
} 