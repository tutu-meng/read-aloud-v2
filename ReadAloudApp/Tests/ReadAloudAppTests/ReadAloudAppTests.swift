//
//  ReadAloudAppTests.swift
//  ReadAloudAppTests
//
//  Created on 2024
//

import XCTest
@testable import ReadAloudApp

final class ReadAloudAppTests: XCTestCase {
    
    func testBookInitialization() {
        // Given
        let testURL = URL(fileURLWithPath: "/test/path/book.txt")
        let testHash = "abc123"
        let testTitle = "Test Book"
        
        // When
        let book = Book(
            title: testTitle,
            fileURL: testURL,
            contentHash: testHash
        )
        
        // Then
        XCTAssertEqual(book.title, testTitle)
        XCTAssertEqual(book.fileURL, testURL)
        XCTAssertEqual(book.contentHash, testHash)
        XCTAssertNotNil(book.id)
    }
} 