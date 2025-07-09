//
//  FileProcessorTests.swift
//  ReadAloudAppTests
//
//  Tests for FILE-1: FileProcessor Service and TextSource abstraction
//  Enhanced for FILE-2: Memory-mapped file loading implementation
//

import XCTest
@testable import ReadAloudApp

final class FileProcessorTests: XCTestCase {
    
    var fileProcessor: FileProcessor!
    var tempTestFile: URL!
    
    override func setUp() {
        super.setUp()
        fileProcessor = FileProcessor()
        
        // Create a temporary test file for realistic testing
        tempTestFile = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).txt")
        let testContent = "This is test content for FileProcessor testing.\nIt contains multiple lines.\nAnd various characters: áéíóú 你好 🎉"
        
        do {
            try testContent.write(to: tempTestFile, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
    }
    
    override func tearDown() {
        // Clean up test file
        if let tempTestFile = tempTestFile {
            try? FileManager.default.removeItem(at: tempTestFile)
        }
        fileProcessor = nil
        super.tearDown()
    }
    
    // MARK: - FileProcessor Tests
    
    func testFileProcessorInitialization() {
        XCTAssertNotNil(fileProcessor, "FileProcessor should be initialized")
    }
    
    func testLoadTextWithValidFile() async throws {
        // Given
        let testURL = tempTestFile!
        
        // When
        let textSource = try await fileProcessor.loadText(from: testURL)
        
        // Then
        switch textSource {
        case .memoryMapped(let nsData):
            XCTAssertGreaterThan(nsData.length, 0, "NSData should contain file content")
            
            // Verify we can read the content
            let loadedData = Data(referencing: nsData)
            let loadedString = String(data: loadedData, encoding: .utf8)
            XCTAssertNotNil(loadedString, "Should be able to decode text from NSData")
            XCTAssertTrue(loadedString!.contains("This is test content"), "Should contain expected content")
        case .streaming:
            XCTFail("Expected memory-mapped result for small test file")
        }
    }
    
    func testLoadTextWithNonExistentFile() async {
        // Given
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/file.txt")
        
        // When/Then
        do {
            _ = try await fileProcessor.loadText(from: nonExistentURL)
            XCTFail("Should throw error for non-existent file")
        } catch {
            guard let appError = error as? AppError else {
                XCTFail("Expected AppError but got \(type(of: error))")
                return
            }
            
            switch appError {
            case .fileNotFound(let filename):
                XCTAssertEqual(filename, nonExistentURL.lastPathComponent, "Should report correct filename")
            default:
                XCTFail("Expected fileNotFound error but got \(appError)")
            }
        }
    }
    
    func testLoadTextWithInvalidURL() async {
        // Given
        let invalidURL = URL(string: "https://example.com/file.txt")!
        
        // When/Then
        do {
            _ = try await fileProcessor.loadText(from: invalidURL)
            XCTFail("Should throw error for non-file URL")
        } catch {
            guard let appError = error as? AppError else {
                XCTFail("Expected AppError but got \(type(of: error))")
                return
            }
            
            switch appError {
            case .fileReadFailed(let filename, _):
                XCTAssertEqual(filename, invalidURL.lastPathComponent, "Should report correct filename")
            default:
                XCTFail("Expected fileReadFailed error but got \(appError)")
            }
        }
    }
    
    func testShouldUseMemoryMappingForSmallFile() throws {
        // Given
        let smallFileURL = tempTestFile!
        
        // When
        let shouldUseMMapping = try fileProcessor.shouldUseMemoryMapping(for: smallFileURL)
        
        // Then
        XCTAssertTrue(shouldUseMMapping, "Small files should use memory mapping")
    }
    
    func testMemoryMapThreshold() {
        // Given/When
        let threshold = FileProcessor.getMemoryMapThreshold()
        
        // Then
        let expectedThreshold: Int64 = Int64(1.5 * 1024 * 1024 * 1024) // 1.5 GB
        XCTAssertEqual(threshold, expectedThreshold, "Memory map threshold should be 1.5GB")
    }
    
    func testLoadTextAsyncMethod() async {
        // This test verifies the method signature is correct and works
        let testURL = tempTestFile!
        
        do {
            let textSource = try await fileProcessor.loadText(from: testURL)
            // Should succeed with memory-mapped result
            switch textSource {
            case .memoryMapped:
                XCTAssertTrue(true, "Successfully loaded with memory mapping")
            case .streaming:
                XCTFail("Expected memory-mapped result for test file")
            }
        } catch {
            XCTFail("Should not throw error for valid test file: \(error)")
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
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("stream-test.txt")
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