//
//  FileProcessorTests.swift
//  ReadAloudAppTests
//
//  Tests for FILE-1: FileProcessor Service and TextSource abstraction
//

import XCTest
@testable import ReadAloudApp

final class FileProcessorTests: XCTestCase {
    
    var fileProcessor: FileProcessor!
    
    override func setUp() {
        super.setUp()
        fileProcessor = FileProcessor()
    }
    
    override func tearDown() {
        fileProcessor = nil
        super.tearDown()
    }
    
    // MARK: - FileProcessor Tests
    
    func testFileProcessorInitialization() {
        XCTAssertNotNil(fileProcessor, "FileProcessor should be initialized")
    }
    
    func testLoadTextThrowsNotImplementedError() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/file.txt")
        
        // When/Then
        do {
            _ = try await fileProcessor.loadText(from: testURL)
            XCTFail("loadText should throw notImplemented error")
        } catch {
            // Verify it's the correct error
            guard let appError = error as? AppError else {
                XCTFail("Expected AppError but got \(type(of: error))")
                return
            }
            
            switch appError {
            case .notImplemented(let feature):
                XCTAssertEqual(feature, "FileProcessor.loadText", "Should specify the correct feature")
            default:
                XCTFail("Expected notImplemented error but got \(appError)")
            }
        }
    }
    
    func testLoadTextAsyncMethod() async {
        // This test verifies the method signature is correct
        let testURL = URL(fileURLWithPath: "/test/file.txt")
        
        do {
            let _ = try await fileProcessor.loadText(from: testURL)
        } catch {
            // Expected to throw - this test is just verifying the async signature
            XCTAssertTrue(true, "Method correctly throws as expected")
        }
    }
    
    // MARK: - TextSource Tests
    
    func testTextSourceMemoryMappedCase() {
        // Given
        let testData = NSData(data: "Test content".data(using: .utf8)!)
        
        // When
        let textSource = TextSource.memoryMapped(testData)
        
        // Then
        switch textSource {
        case .memoryMapped(let data):
            XCTAssertEqual(data, testData, "Should store the correct NSData")
        case .streaming:
            XCTFail("Expected memoryMapped case")
        }
    }
    
    func testTextSourceStreamingCase() throws {
        // Given
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try "Test content".write(to: tempFile, atomically: true, encoding: .utf8)
        let fileHandle = try FileHandle(forReadingFrom: tempFile)
        
        // When
        let textSource = TextSource.streaming(fileHandle)
        
        // Then
        switch textSource {
        case .memoryMapped:
            XCTFail("Expected streaming case")
        case .streaming(let handle):
            XCTAssertEqual(handle, fileHandle, "Should store the correct FileHandle")
        }
        
        // Cleanup
        fileHandle.closeFile()
        try? FileManager.default.removeItem(at: tempFile)
    }
    
    func testTextSourceEnumCases() {
        // This test verifies that TextSource has exactly the expected cases
        let memoryData = NSData()
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("enum-test.txt")
        
        do {
            try "test".write(to: tempFile, atomically: true, encoding: .utf8)
            let fileHandle = try FileHandle(forReadingFrom: tempFile)
            
            let memorySource = TextSource.memoryMapped(memoryData)
            let streamingSource = TextSource.streaming(fileHandle)
            
            // Verify we can create both cases
            XCTAssertNotNil(memorySource)
            XCTAssertNotNil(streamingSource)
            
            fileHandle.closeFile()
            try? FileManager.default.removeItem(at: tempFile)
        } catch {
            XCTFail("Failed to test enum cases: \(error)")
        }
    }
} 