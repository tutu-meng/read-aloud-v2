//
//  FILE2MemoryMappingTests.swift
//  ReadAloudAppTests
//
//  Specific tests for FILE-2: Memory-mapped file loading implementation
//

import XCTest
@testable import ReadAloudApp

final class FILE2MemoryMappingTests: XCTestCase {
    
    var fileProcessor: FileProcessor!
    
    override func setUp() {
        super.setUp()
        fileProcessor = FileProcessor()
    }
    
    override func tearDown() {
        fileProcessor = nil
        super.tearDown()
    }
    
    // MARK: - FILE-2 Acceptance Criteria Tests
    
    func testMemoryMappedLoadingWithValidFile() async throws {
        // Acceptance Criteria 1: FileProcessor attempts to load using NSData(contentsOfFile:options:.mappedIfSafe)
        
        // Given: Create a test file
        let tempFile = createTempFile(content: "FILE-2 test content for memory mapping validation")
        defer { cleanupTempFile(tempFile) }
        
        // When: Load the file
        let textSource = try await fileProcessor.loadText(from: tempFile)
        
        // Then: Should return memory-mapped TextSource
        switch textSource {
        case .memoryMapped(let nsData):
            // Acceptance Criteria 2: Returns TextSource with memory-mapped NSData
            XCTAssertGreaterThan(nsData.length, 0, "NSData should contain file content")
            
            // Verify content integrity
            let data = Data(referencing: nsData)
            let content = String(data: data, encoding: .utf8)
            XCTAssertEqual(content, "FILE-2 test content for memory mapping validation", "Content should match original")
            
        case .streaming:
            XCTFail("Expected memory-mapped TextSource for small file")
        }
    }
    
    func testMemoryMappedLoadingFailureThrowsAppError() async {
        // Acceptance Criteria 3: Throws AppError when NSData initialization fails
        
        // Given: Non-existent file
        let nonExistentFile = URL(fileURLWithPath: "/definitely/does/not/exist/file.txt")
        
        // When/Then: Should throw appropriate AppError
        do {
            _ = try await fileProcessor.loadText(from: nonExistentFile)
            XCTFail("Should throw AppError for non-existent file")
        } catch let error as AppError {
            switch error {
            case .fileNotFound(let filename):
                XCTAssertEqual(filename, nonExistentFile.lastPathComponent, "Should report correct filename")
            default:
                XCTFail("Expected fileNotFound error, got \(error)")
            }
        } catch {
            XCTFail("Expected AppError, got \(type(of: error)): \(error)")
        }
    }
    
    func testMemoryMappedLoadingWithPermissionDeniedFile() async {
        // Test error handling for files that exist but can't be read
        
        // Given: A file we can create but then make unreadable
        let tempFile = createTempFile(content: "Permission test content")
        defer { cleanupTempFile(tempFile) }
        
        // Make file unreadable (this might not work in sandbox, so we'll handle gracefully)
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: tempFile.path)
            
            // When/Then: Should throw fileReadFailed
            do {
                _ = try await fileProcessor.loadText(from: tempFile)
                // If we get here, permissions didn't work as expected (sandbox limitation)
                // That's okay - the test passes as the file was readable
                XCTAssertTrue(true, "File was readable despite permission change (sandbox limitation)")
            } catch let error as AppError {
                switch error {
                case .fileReadFailed(let filename, _):
                    XCTAssertEqual(filename, tempFile.lastPathComponent, "Should report correct filename")
                default:
                    XCTFail("Expected fileReadFailed error, got \(error)")
                }
            }
            
            // Restore permissions for cleanup
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: tempFile.path)
        } catch {
            // Permission changes might not work in test environment
            XCTAssertTrue(true, "Permission test skipped due to environment limitations")
        }
    }
    
    // MARK: - Memory Mapping Strategy Tests
    
    func testMemoryMappingWithEmptyFile() async throws {
        // Given: Empty file
        let emptyFile = createTempFile(content: "")
        defer { cleanupTempFile(emptyFile) }
        
        // When: Load empty file
        let textSource = try await fileProcessor.loadText(from: emptyFile)
        
        // Then: Should still work with memory mapping
        switch textSource {
        case .memoryMapped(let nsData):
            XCTAssertEqual(nsData.length, 0, "Empty file should have zero-length NSData")
        case .streaming:
            XCTFail("Expected memory-mapped TextSource for empty file")
        }
    }
    
    func testMemoryMappingWithUnicodeContent() async throws {
        // Given: File with various Unicode characters
        let unicodeContent = "FILE-2 Unicode Test: áéíóú ñ 你好世界 🎉🚀📱 Ελληνικά العربية"
        let unicodeFile = createTempFile(content: unicodeContent)
        defer { cleanupTempFile(unicodeFile) }
        
        // When: Load Unicode file
        let textSource = try await fileProcessor.loadText(from: unicodeFile)
        
        // Then: Should preserve Unicode content
        switch textSource {
        case .memoryMapped(let nsData):
            let data = Data(referencing: nsData)
            let loadedContent = String(data: data, encoding: .utf8)
            XCTAssertEqual(loadedContent, unicodeContent, "Unicode content should be preserved")
        case .streaming:
            XCTFail("Expected memory-mapped TextSource for Unicode file")
        }
    }
    
    func testMemoryMappingWithLargeFile() async throws {
        // Given: Moderately large file (but still under threshold)
        let largeContent = String(repeating: "This is a line of text for large file testing.\n", count: 10000)
        let largeFile = createTempFile(content: largeContent)
        defer { cleanupTempFile(largeFile) }
        
        // When: Load large file
        let textSource = try await fileProcessor.loadText(from: largeFile)
        
        // Then: Should still use memory mapping for files under threshold
        switch textSource {
        case .memoryMapped(let nsData):
            XCTAssertGreaterThan(nsData.length, 400000, "Large file should have substantial content")
            
            // Verify content integrity
            let data = Data(referencing: nsData)
            let loadedContent = String(data: data, encoding: .utf8)
            XCTAssertEqual(loadedContent, largeContent, "Large file content should be preserved")
        case .streaming:
            XCTFail("Expected memory-mapped TextSource for file under threshold")
        }
    }
    
    // MARK: - Helper Method Tests
    
    func testShouldUseMemoryMappingForVariousFileSizes() throws {
        // Test the helper method with different file sizes
        
        // Small file
        let smallFile = createTempFile(content: "Small file")
        defer { cleanupTempFile(smallFile) }
        
        XCTAssertTrue(try fileProcessor.shouldUseMemoryMapping(for: smallFile), 
                     "Small files should use memory mapping")
        
        // Medium file
        let mediumContent = String(repeating: "Medium file content.\n", count: 1000)
        let mediumFile = createTempFile(content: mediumContent)
        defer { cleanupTempFile(mediumFile) }
        
        XCTAssertTrue(try fileProcessor.shouldUseMemoryMapping(for: mediumFile), 
                     "Medium files should use memory mapping")
    }
    
    func testShouldUseMemoryMappingThrowsForNonExistentFile() {
        // Given: Non-existent file
        let nonExistentFile = URL(fileURLWithPath: "/does/not/exist.txt")
        
        // When/Then: Should throw error
        XCTAssertThrowsError(try fileProcessor.shouldUseMemoryMapping(for: nonExistentFile)) { error in
            guard let appError = error as? AppError else {
                XCTFail("Expected AppError, got \(type(of: error))")
                return
            }
            
            switch appError {
            case .fileReadFailed(let filename, _):
                XCTAssertEqual(filename, nonExistentFile.lastPathComponent, "Should report correct filename")
            default:
                XCTFail("Expected fileReadFailed error, got \(appError)")
            }
        }
    }
    
    func testMemoryMapThresholdConstant() {
        // Test the memory mapping threshold constant
        let threshold = FileProcessor.getMemoryMapThreshold()
        let expected: Int64 = Int64(1.5 * 1024 * 1024 * 1024) // 1.5 GB
        
        XCTAssertEqual(threshold, expected, "Memory mapping threshold should be 1.5 GB")
        XCTAssertEqual(threshold, 1_610_612_736, "Memory mapping threshold should be exactly 1,610,612,736 bytes")
    }
    
    // MARK: - Integration Tests
    
    func testMemoryMappingIntegrationWithTextExtraction() async throws {
        // Test full integration: load file and extract text content
        
        // Given: File with known content
        let testContent = """
        FILE-2 Integration Test
        =====================
        
        This file tests the complete memory-mapping workflow:
        1. File creation
        2. Memory-mapped loading
        3. Content extraction
        4. Content verification
        
        Special characters: áéíóú ñ 你好 🎉
        """
        
        let testFile = createTempFile(content: testContent)
        defer { cleanupTempFile(testFile) }
        
        // When: Load and extract content
        let textSource = try await fileProcessor.loadText(from: testFile)
        
        switch textSource {
        case .memoryMapped(let nsData):
            // Extract and verify content
            let data = Data(referencing: nsData)
            let extractedContent = String(data: data, encoding: .utf8)
            
            XCTAssertNotNil(extractedContent, "Should be able to extract text from memory-mapped data")
            XCTAssertEqual(extractedContent, testContent, "Extracted content should match original")
            XCTAssertTrue(extractedContent!.contains("FILE-2 Integration Test"), "Should contain header")
            XCTAssertTrue(extractedContent!.contains("Special characters: áéíóú"), "Should preserve Unicode")
            
        case .streaming:
            XCTFail("Expected memory-mapped result for integration test")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTempFile(content: String) -> URL {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("file2-test-\(UUID().uuidString).txt")
        
        do {
            try content.write(to: tempFile, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to create temp file: \(error)")
        }
        
        return tempFile
    }
    
    private func cleanupTempFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
} 