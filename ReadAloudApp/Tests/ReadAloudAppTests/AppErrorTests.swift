//
//  AppErrorTests.swift
//  ReadAloudAppTests
//
//  Created on 2024
//

import XCTest
@testable import ReadAloudApp

final class AppErrorTests: XCTestCase {
    
    // MARK: - LocalizedError Conformance Tests
    
    func testFileNotFoundError() {
        let error = AppError.fileNotFound(filename: "test.txt")
        
        XCTAssertEqual(error.errorCode, "FILE_001")
        XCTAssertTrue(error.errorDescription?.contains("test.txt") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("could not be found") ?? false)
        XCTAssertNotNil(error.failureReason)
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertEqual(error.helpAnchor, "file-errors")
        XCTAssertTrue(error.isRecoverable)
        XCTAssertEqual(error.severity, .warning)
    }
    
    func testFileReadFailedError() {
        let underlyingError = NSError(domain: "TestDomain", code: 100, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
        let error = AppError.fileReadFailed(filename: "document.txt", underlyingError: underlyingError)
        
        XCTAssertEqual(error.errorCode, "FILE_002")
        XCTAssertTrue(error.errorDescription?.contains("document.txt") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Permission denied") ?? false)
        XCTAssertNotNil(error.failureReason)
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertEqual(error.severity, .error)
    }
    
    func testFileReadFailedErrorWithoutUnderlying() {
        let error = AppError.fileReadFailed(filename: "document.txt", underlyingError: nil)
        
        XCTAssertTrue(error.errorDescription?.contains("Unknown error") ?? false)
    }
    
    func testFileTooLargeError() {
        let error = AppError.fileTooLarge(filename: "huge.txt", sizeInMB: 2500.5, maxSizeInMB: 2000.0)
        
        XCTAssertEqual(error.errorCode, "FILE_003")
        XCTAssertTrue(error.errorDescription?.contains("2500.5") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("2000") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("too large") ?? false)
        XCTAssertEqual(error.severity, .info)
    }
    
    func testInvalidFileFormatError() {
        let error = AppError.invalidFileFormat(filename: "file.doc", expectedFormats: ["txt", "rtf", "md"])
        
        XCTAssertEqual(error.errorCode, "FILE_004")
        XCTAssertTrue(error.errorDescription?.contains("file.doc") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("txt, rtf, md") ?? false)
        XCTAssertEqual(error.severity, .warning)
    }
    
    func testPaginationFailedError() {
        let error = AppError.paginationFailed(reason: "Font metrics calculation failed")
        
        XCTAssertEqual(error.errorCode, "TEXT_001")
        XCTAssertTrue(error.errorDescription?.contains("Font metrics calculation failed") ?? false)
        XCTAssertEqual(error.severity, .error)
    }
    
    func testEncodingError() {
        let error = AppError.encodingError(filename: "unicode.txt")
        
        XCTAssertEqual(error.errorCode, "TEXT_002")
        XCTAssertTrue(error.errorDescription?.contains("unicode.txt") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("UTF-8") ?? false)
        XCTAssertEqual(error.severity, .warning)
    }
    
    func testTTSError() {
        let error = AppError.ttsError(reason: "Audio engine failed to initialize")
        
        XCTAssertEqual(error.errorCode, "TTS_001")
        XCTAssertTrue(error.errorDescription?.contains("Audio engine failed") ?? false)
        XCTAssertEqual(error.helpAnchor, "speech-errors")
    }
    
    func testVoiceNotAvailableError() {
        let error = AppError.voiceNotAvailable(voiceName: "Alex")
        
        XCTAssertEqual(error.errorCode, "TTS_002")
        XCTAssertTrue(error.errorDescription?.contains("Alex") ?? false)
        XCTAssertFalse(error.shouldReport)
        XCTAssertEqual(error.severity, .info)
    }
    
    func testTTSNotSupportedError() {
        let error = AppError.ttsNotSupported
        
        XCTAssertEqual(error.errorCode, "TTS_003")
        XCTAssertFalse(error.isRecoverable)
        XCTAssertEqual(error.severity, .critical)
    }
    
    func testSaveFailedError() {
        let underlyingError = NSError(domain: "TestDomain", code: 200, userInfo: [NSLocalizedDescriptionKey: "Disk full"])
        let error = AppError.saveFailed(dataType: "user settings", underlyingError: underlyingError)
        
        XCTAssertEqual(error.errorCode, "STORAGE_001")
        XCTAssertTrue(error.errorDescription?.contains("user settings") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Disk full") ?? false)
        XCTAssertEqual(error.severity, .error)
    }
    
    func testLoadFailedError() {
        let error = AppError.loadFailed(dataType: "reading progress", underlyingError: nil)
        
        XCTAssertEqual(error.errorCode, "STORAGE_002")
        XCTAssertTrue(error.errorDescription?.contains("reading progress") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Unknown error") ?? false)
    }
    
    func testInsufficientStorageError() {
        let error = AppError.insufficientStorage(requiredMB: 100.5, availableMB: 50.2)
        
        XCTAssertEqual(error.errorCode, "STORAGE_003")
        XCTAssertTrue(error.errorDescription?.contains("100.5") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("50.2") ?? false)
    }
    
    func testNoNetworkConnectionError() {
        let error = AppError.noNetworkConnection
        
        XCTAssertEqual(error.errorCode, "NET_001")
        XCTAssertTrue(error.errorDescription?.contains("internet connection") ?? false)
        XCTAssertEqual(error.helpAnchor, "network-errors")
    }
    
    func testDownloadFailedError() {
        let underlyingError = NSError(domain: "NSURLErrorDomain", code: -1009, userInfo: [NSLocalizedDescriptionKey: "Network timeout"])
        let error = AppError.downloadFailed(url: "https://example.com/file.txt", underlyingError: underlyingError)
        
        XCTAssertEqual(error.errorCode, "NET_002")
        XCTAssertTrue(error.errorDescription?.contains("example.com") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Network timeout") ?? false)
    }
    
    func testUnknownError() {
        let underlyingError = NSError(domain: "UnknownDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Something went wrong"])
        let error = AppError.unknown(underlyingError: underlyingError)
        
        XCTAssertEqual(error.errorCode, "GEN_001")
        XCTAssertEqual(error.errorDescription, "Something went wrong")
        XCTAssertEqual(error.severity, .critical)
        XCTAssertTrue(error.shouldReport)
    }
    
    func testNotImplementedError() {
        let error = AppError.notImplemented(feature: "Cloud Sync")
        
        XCTAssertEqual(error.errorCode, "GEN_002")
        XCTAssertTrue(error.errorDescription?.contains("Cloud Sync") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Coming soon") ?? false)
        XCTAssertFalse(error.isRecoverable)
        XCTAssertFalse(error.shouldReport)
    }
    
    // MARK: - Error Properties Tests
    
    func testAllErrorsHaveDescriptions() {
        let errors: [AppError] = [
            .fileNotFound(filename: "test"),
            .fileReadFailed(filename: "test", underlyingError: nil),
            .fileTooLarge(filename: "test", sizeInMB: 100, maxSizeInMB: 50),
            .invalidFileFormat(filename: "test", expectedFormats: ["txt"]),
            .paginationFailed(reason: "test"),
            .encodingError(filename: "test"),
            .ttsError(reason: "test"),
            .voiceNotAvailable(voiceName: "test"),
            .ttsNotSupported,
            .saveFailed(dataType: "test", underlyingError: nil),
            .loadFailed(dataType: "test", underlyingError: nil),
            .insufficientStorage(requiredMB: 100, availableMB: 50),
            .noNetworkConnection,
            .downloadFailed(url: "test", underlyingError: nil),
            .unknown(underlyingError: nil),
            .notImplemented(feature: "test")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) missing description")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "Error \(error) has empty description")
            XCTAssertNotNil(error.failureReason, "Error \(error) missing failure reason")
            XCTAssertNotNil(error.recoverySuggestion, "Error \(error) missing recovery suggestion")
            XCTAssertNotNil(error.helpAnchor, "Error \(error) missing help anchor")
            XCTAssertFalse(error.errorCode.isEmpty, "Error \(error) has empty error code")
        }
    }
    
    func testErrorCodeUniqueness() {
        let errors: [AppError] = [
            .fileNotFound(filename: "test"),
            .fileReadFailed(filename: "test", underlyingError: nil),
            .fileTooLarge(filename: "test", sizeInMB: 100, maxSizeInMB: 50),
            .invalidFileFormat(filename: "test", expectedFormats: ["txt"]),
            .paginationFailed(reason: "test"),
            .encodingError(filename: "test"),
            .ttsError(reason: "test"),
            .voiceNotAvailable(voiceName: "test"),
            .ttsNotSupported,
            .saveFailed(dataType: "test", underlyingError: nil),
            .loadFailed(dataType: "test", underlyingError: nil),
            .insufficientStorage(requiredMB: 100, availableMB: 50),
            .noNetworkConnection,
            .downloadFailed(url: "test", underlyingError: nil),
            .unknown(underlyingError: nil),
            .notImplemented(feature: "test")
        ]
        
        let errorCodes = errors.map { $0.errorCode }
        let uniqueCodes = Set(errorCodes)
        
        XCTAssertEqual(errorCodes.count, uniqueCodes.count, "Duplicate error codes found")
    }
    
    // MARK: - AppCoordinator Integration Test
    
    func testAppCoordinatorErrorHandling() {
        let coordinator = AppCoordinator()
        
        // Test with AppError
        let appError = AppError.fileNotFound(filename: "missing.txt")
        coordinator.handleError(appError)
        
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertTrue(coordinator.errorMessage?.contains("missing.txt") ?? false)
        
        // Clear error
        coordinator.clearError()
        XCTAssertNil(coordinator.errorMessage)
        
        // Test with generic Error
        let genericError = NSError(domain: "TestDomain", code: 500, userInfo: [NSLocalizedDescriptionKey: "Generic error"])
        coordinator.handleError(genericError)
        
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertEqual(coordinator.errorMessage, "Generic error")
    }
} 