//
//  AppError.swift
//  ReadAloudApp
//
//  Created on 2024
//

import Foundation

/// Centralized error handling for the ReadAloudApp
/// Provides domain-specific errors with user-friendly descriptions
enum AppError: Error {
    // MARK: - File Operation Errors
    
    /// File not found at the specified path
    case fileNotFound(filename: String)
    
    /// Failed to read file contents
    case fileReadFailed(filename: String, underlyingError: Error?)
    
    /// File is too large to process
    case fileTooLarge(filename: String, sizeInMB: Double, maxSizeInMB: Double)
    
    /// Invalid file format
    case invalidFileFormat(filename: String, expectedFormats: [String])
    
    // MARK: - Text Processing Errors
    
    /// Failed to paginate text content
    case paginationFailed(reason: String)
    
    /// Text encoding issues
    case encodingError(filename: String)
    
    // MARK: - Text-to-Speech Errors
    
    /// TTS engine error
    case ttsError(reason: String)
    
    /// Voice not available
    case voiceNotAvailable(voiceName: String)
    
    /// TTS not supported on device
    case ttsNotSupported
    
    // MARK: - Storage Errors
    
    /// Failed to save data
    case saveFailed(dataType: String, underlyingError: Error?)
    
    /// Failed to load data
    case loadFailed(dataType: String, underlyingError: Error?)
    
    /// Insufficient storage space
    case insufficientStorage(requiredMB: Double, availableMB: Double)
    
    // MARK: - Network Errors
    
    /// Network connection required but not available
    case noNetworkConnection
    
    /// Download failed
    case downloadFailed(url: String, underlyingError: Error?)
    
    // MARK: - General Errors
    
    /// Unknown error occurred
    case unknown(underlyingError: Error?)
    
    /// Feature not yet implemented
    case notImplemented(feature: String)
}

// MARK: - LocalizedError Conformance

extension AppError: LocalizedError {
    /// User-friendly error description
    var errorDescription: String? {
        switch self {
        // File Operation Errors
        case .fileNotFound(let filename):
            return "The file '\(filename)' could not be found. Please check if the file exists and try again."
            
        case .fileReadFailed(let filename, let underlyingError):
            let details = underlyingError?.localizedDescription ?? "Unknown error"
            return "Failed to read the file '\(filename)'. Error: \(details)"
            
        case .fileTooLarge(let filename, let sizeInMB, let maxSizeInMB):
            return "The file '\(filename)' is too large (\(String(format: "%.1f", sizeInMB)) MB). Maximum supported size is \(String(format: "%.0f", maxSizeInMB)) MB."
            
        case .invalidFileFormat(let filename, let expectedFormats):
            let formats = expectedFormats.joined(separator: ", ")
            return "The file '\(filename)' is not in a supported format. Please use one of the following formats: \(formats)."
            
        // Text Processing Errors
        case .paginationFailed(let reason):
            return "Failed to process the text for display. \(reason)"
            
        case .encodingError(let filename):
            return "The file '\(filename)' contains text that cannot be properly decoded. Please ensure the file uses UTF-8 encoding."
            
        // Text-to-Speech Errors
        case .ttsError(let reason):
            return "Text-to-Speech error: \(reason)"
            
        case .voiceNotAvailable(let voiceName):
            return "The voice '\(voiceName)' is not available. Please select a different voice in Settings."
            
        case .ttsNotSupported:
            return "Text-to-Speech is not supported on this device."
            
        // Storage Errors
        case .saveFailed(let dataType, let underlyingError):
            let details = underlyingError?.localizedDescription ?? "Unknown error"
            return "Failed to save \(dataType). Error: \(details)"
            
        case .loadFailed(let dataType, let underlyingError):
            let details = underlyingError?.localizedDescription ?? "Unknown error"
            return "Failed to load \(dataType). Error: \(details)"
            
        case .insufficientStorage(let requiredMB, let availableMB):
            return "Not enough storage space. Required: \(String(format: "%.1f", requiredMB)) MB, Available: \(String(format: "%.1f", availableMB)) MB."
            
        // Network Errors
        case .noNetworkConnection:
            return "No internet connection available. Please check your network settings and try again."
            
        case .downloadFailed(let url, let underlyingError):
            let details = underlyingError?.localizedDescription ?? "Unknown error"
            return "Failed to download from '\(url)'. Error: \(details)"
            
        // General Errors
        case .unknown(let underlyingError):
            let details = underlyingError?.localizedDescription ?? "An unexpected error occurred"
            return details
            
        case .notImplemented(let feature):
            return "The feature '\(feature)' is not yet implemented. Coming soon!"
        }
    }
    
    /// Additional information about what failed
    var failureReason: String? {
        switch self {
        case .fileNotFound:
            return "The file does not exist at the specified location."
        case .fileReadFailed:
            return "The file could not be opened or read."
        case .fileTooLarge:
            return "The file exceeds the maximum size limit."
        case .invalidFileFormat:
            return "The file format is not supported."
        case .paginationFailed:
            return "Text layout calculation failed."
        case .encodingError:
            return "Text encoding is incompatible."
        case .ttsError:
            return "Speech synthesis encountered an error."
        case .voiceNotAvailable:
            return "The requested voice is not installed."
        case .ttsNotSupported:
            return "Device does not support text-to-speech."
        case .saveFailed:
            return "Data could not be persisted."
        case .loadFailed:
            return "Data could not be retrieved."
        case .insufficientStorage:
            return "Device storage is full."
        case .noNetworkConnection:
            return "Network is unreachable."
        case .downloadFailed:
            return "Network download failed."
        case .unknown:
            return "An unexpected error occurred."
        case .notImplemented:
            return "Feature is not yet available."
        }
    }
    
    /// Suggested recovery action
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Please select a different file or check if the file has been moved or deleted."
        case .fileReadFailed:
            return "Try closing and reopening the file, or check file permissions."
        case .fileTooLarge:
            return "Try using a smaller file or split the file into smaller parts."
        case .invalidFileFormat:
            return "Convert the file to a supported format and try again."
        case .paginationFailed:
            return "Try adjusting the font size or restarting the app."
        case .encodingError:
            return "Re-save the file with UTF-8 encoding and try again."
        case .ttsError:
            return "Try restarting the app or check system audio settings."
        case .voiceNotAvailable:
            return "Go to Settings and select an available voice."
        case .ttsNotSupported:
            return "This device does not support text-to-speech functionality."
        case .saveFailed:
            return "Check available storage space and try again."
        case .loadFailed:
            return "Try restarting the app or reinstalling if the problem persists."
        case .insufficientStorage:
            return "Free up storage space by deleting unused files or apps."
        case .noNetworkConnection:
            return "Enable Wi-Fi or cellular data and try again."
        case .downloadFailed:
            return "Check your internet connection and try again."
        case .unknown:
            return "Try restarting the app. If the problem persists, please contact support."
        case .notImplemented:
            return "This feature will be available in a future update."
        }
    }
    
    /// Help anchor for documentation
    var helpAnchor: String? {
        switch self {
        case .fileNotFound, .fileReadFailed, .fileTooLarge, .invalidFileFormat:
            return "file-errors"
        case .paginationFailed, .encodingError:
            return "text-processing-errors"
        case .ttsError, .voiceNotAvailable, .ttsNotSupported:
            return "speech-errors"
        case .saveFailed, .loadFailed, .insufficientStorage:
            return "storage-errors"
        case .noNetworkConnection, .downloadFailed:
            return "network-errors"
        case .unknown, .notImplemented:
            return "general-errors"
        }
    }
}

// MARK: - Error Code

extension AppError {
    /// Unique error code for logging and debugging
    var errorCode: String {
        switch self {
        case .fileNotFound: return "FILE_001"
        case .fileReadFailed: return "FILE_002"
        case .fileTooLarge: return "FILE_003"
        case .invalidFileFormat: return "FILE_004"
        case .paginationFailed: return "TEXT_001"
        case .encodingError: return "TEXT_002"
        case .ttsError: return "TTS_001"
        case .voiceNotAvailable: return "TTS_002"
        case .ttsNotSupported: return "TTS_003"
        case .saveFailed: return "STORAGE_001"
        case .loadFailed: return "STORAGE_002"
        case .insufficientStorage: return "STORAGE_003"
        case .noNetworkConnection: return "NET_001"
        case .downloadFailed: return "NET_002"
        case .unknown: return "GEN_001"
        case .notImplemented: return "GEN_002"
        }
    }
}

// MARK: - Convenience Methods

extension AppError {
    /// Check if this is a recoverable error
    var isRecoverable: Bool {
        switch self {
        case .ttsNotSupported, .notImplemented:
            return false
        default:
            return true
        }
    }
    
    /// Check if this error should be reported to analytics
    var shouldReport: Bool {
        switch self {
        case .notImplemented, .voiceNotAvailable:
            return false
        default:
            return true
        }
    }
    
    /// Get severity level for logging
    var severity: ErrorSeverity {
        switch self {
        case .unknown, .ttsNotSupported:
            return .critical
        case .fileReadFailed, .paginationFailed, .saveFailed, .loadFailed:
            return .error
        case .fileNotFound, .invalidFileFormat, .encodingError, .ttsError, .downloadFailed:
            return .warning
        case .fileTooLarge, .voiceNotAvailable, .insufficientStorage, .noNetworkConnection, .notImplemented:
            return .info
        }
    }
}

/// Error severity levels for logging and monitoring
enum ErrorSeverity: String {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
} 