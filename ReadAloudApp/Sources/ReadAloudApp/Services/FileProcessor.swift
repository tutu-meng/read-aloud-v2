//
//  FileProcessor.swift
//  ReadAloudApp
//
//  Created on FILE-1 implementation
//  Enhanced for FILE-2: Memory-mapped file loading
//  Enhanced for FILE-3: Streaming file loading with NSFileHandle
//

import Foundation

/// TextSource represents an abstraction layer for loaded text data.
/// It decouples the rest of the application from the specific file reading implementation.
public enum TextSource {
    /// Memory-mapped file data for optimal performance with files < 1.5GB
    case memoryMapped(NSData)
    
    /// Streaming file handle for very large files (>= 1.5GB)
    case streaming(FileHandle)
}

/// FileProcessor encapsulates all file I/O logic for the ReadAloudApp.
/// It implements a hybrid strategy for loading text files based on their size.
public class FileProcessor {
    
    /// The size threshold (in bytes) below which files will be memory-mapped.
    /// Files larger than this will use streaming to avoid virtual memory limits.
    private static let memoryMapThreshold: Int64 = Int64(1.5 * 1024 * 1024 * 1024) // 1.5 GB
    
    // MARK: - Public Methods
    
    /// Asynchronously loads text from the specified file URL.
    ///
    /// This method implements a hybrid loading strategy:
    /// - Files < 1.5GB: Memory-mapped using NSData(contentsOfFile:options:.mappedIfSafe)
    /// - Files >= 1.5GB: Streaming using NSFileHandle to avoid virtual memory limits
    /// - Returns appropriate TextSource based on file size and loading strategy
    ///
    /// - Parameter url: The URL of the text file to load
    /// - Returns: A TextSource representing the loaded text data
    /// - Throws: AppError if the file cannot be loaded
    public func loadText(from url: URL) async throws -> TextSource {
        debugPrint("📄 FileProcessor: Attempting to load file: \(url.lastPathComponent)")
        
        // Validate URL and file existence
        guard url.isFileURL else {
            debugPrint("❌ FileProcessor: Invalid file URL: \(url)")
            throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: nil)
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            debugPrint("❌ FileProcessor: File not found: \(url.path)")
            throw AppError.fileNotFound(filename: url.lastPathComponent)
        }
        
        // Determine loading strategy based on file size
        let shouldUseMemoryMapping = try self.shouldUseMemoryMapping(for: url)
        
        if shouldUseMemoryMapping {
            debugPrint("🗺️ FileProcessor: Using memory-mapped loading strategy")
            return try await loadTextUsingMemoryMapping(from: url)
        } else {
            debugPrint("🔄 FileProcessor: Using streaming loading strategy")
            return try await loadTextUsingStreaming(from: url)
        }
    }
    
    // MARK: - Private Loading Methods
    
    /// Load text using memory-mapped strategy for files < 1.5GB
    /// - Parameter url: The URL of the text file to load
    /// - Returns: TextSource.memoryMapped with NSData
    /// - Throws: AppError if memory mapping fails
    private func loadTextUsingMemoryMapping(from url: URL) async throws -> TextSource {
        debugPrint("🗺️ FileProcessor: Attempting memory-mapped loading...")
        
        do {
            let nsData = try NSData(contentsOfFile: url.path, options: .mappedIfSafe)
            debugPrint("✅ FileProcessor: Successfully loaded \(nsData.length) bytes via memory mapping")
            return TextSource.memoryMapped(nsData)
        } catch {
            debugPrint("❌ FileProcessor: Memory-mapped loading failed for: \(url.path) - \(error)")
            throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: error)
        }
    }
    
    /// Load text using streaming strategy for files >= 1.5GB
    /// - Parameter url: The URL of the text file to load
    /// - Returns: TextSource.streaming with FileHandle
    /// - Throws: AppError if file handle creation fails
    private func loadTextUsingStreaming(from url: URL) async throws -> TextSource {
        debugPrint("🔄 FileProcessor: Attempting streaming loading...")
        
        return try openFileForStreaming(from: url)
    }
    
    /// Private method to open a file for reading using NSFileHandle
    /// - Parameter url: The URL of the text file to open
    /// - Returns: TextSource.streaming with configured FileHandle
    /// - Throws: AppError if file handle creation fails
    private func openFileForStreaming(from url: URL) throws -> TextSource {
        debugPrint("🔄 FileProcessor: Opening file handle for streaming: \(url.lastPathComponent)")
        
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            debugPrint("✅ FileProcessor: Successfully opened file handle for streaming")
            return TextSource.streaming(fileHandle)
        } catch {
            debugPrint("❌ FileProcessor: Failed to open file handle for: \(url.path) - \(error)")
            throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if a file is suitable for memory mapping based on its size
    /// - Parameter url: The file URL to check
    /// - Returns: True if the file should be memory-mapped, false if it should be streamed
    /// - Throws: AppError if file attributes cannot be read
    public func shouldUseMemoryMapping(for url: URL) throws -> Bool {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = fileAttributes[.size] as? Int64 else {
                throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: nil)
            }
            
            debugPrint("📄 FileProcessor: File size: \(fileSize) bytes")
            
            let shouldUseMemoryMapping = fileSize < Self.memoryMapThreshold
            if shouldUseMemoryMapping {
                debugPrint("📝 FileProcessor: File size (\(fileSize)) is below memory mapping threshold (\(Self.memoryMapThreshold))")
            } else {
                debugPrint("⚠️ FileProcessor: File size (\(fileSize)) exceeds memory mapping threshold (\(Self.memoryMapThreshold))")
            }
            
            return shouldUseMemoryMapping
        } catch {
            throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: error)
        }
    }
    
    /// Get the memory mapping threshold
    /// - Returns: The size threshold in bytes for memory mapping vs streaming
    public static func getMemoryMapThreshold() -> Int64 {
        return memoryMapThreshold
    }
} 