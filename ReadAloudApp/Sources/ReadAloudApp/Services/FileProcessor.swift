//
//  FileProcessor.swift
//  ReadAloudApp
//
//  Created on FILE-1 implementation
//  Enhanced for FILE-2: Memory-mapped file loading
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
    /// This method implements the primary loading strategy using memory-mapping:
    /// - Attempts to load files using NSData(contentsOfFile:options:.mappedIfSafe)
    /// - Returns TextSource.memoryMapped for successful loads
    /// - Throws AppError.fileReadFailed for any loading failures
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
        
        // Get file size for logging
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = fileAttributes[.size] as? Int64 {
                debugPrint("📄 FileProcessor: File size: \(fileSize) bytes")
                
                // Log if file exceeds memory mapping threshold
                if fileSize >= Self.memoryMapThreshold {
                    debugPrint("⚠️ FileProcessor: File size (\(fileSize)) exceeds memory mapping threshold (\(Self.memoryMapThreshold))")
                }
            }
        } catch {
            debugPrint("⚠️ FileProcessor: Could not get file attributes: \(error)")
        }
        
        // Attempt memory-mapped loading
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
            
            return fileSize < Self.memoryMapThreshold
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