//
//  FileProcessor.swift
//  ReadAloudApp
//
//  Created on FILE-1 implementation
//  Enhanced for FILE-2: Memory-mapped file loading
//  Enhanced for FILE-3: Streaming file loading with NSFileHandle
//  Enhanced for PERSIST-2: File copying and hash calculation
//

import Foundation
import CryptoKit

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
    
    /// Securely copy a file to the app's Documents directory and return the new URL
    /// - Parameters:
    ///   - sourceURL: The original file URL (may be security-scoped)
    ///   - filename: Optional custom filename, defaults to original filename
    /// - Returns: URL of the copied file in the Documents directory
    /// - Throws: AppError if copying fails
    public func copyFileToDocuments(from sourceURL: URL, filename: String? = nil) async throws -> URL {
        debugPrint("📄 FileProcessor: Copying file to Documents directory: \(sourceURL.lastPathComponent)")
        
        // Get the Documents directory
        let documentsDirectory = try getDocumentsDirectory()
        
        // Create filename (use provided name or original filename)
        let finalFilename = filename ?? sourceURL.lastPathComponent
        let destinationURL = documentsDirectory.appendingPathComponent(finalFilename)
        
        // Handle potential filename conflicts
        let uniqueDestinationURL = try generateUniqueFilename(for: destinationURL)
        
        // Perform the file copy
        do {
            try FileManager.default.copyItem(at: sourceURL, to: uniqueDestinationURL)
            debugPrint("✅ FileProcessor: Successfully copied file to: \(uniqueDestinationURL.path)")
            return uniqueDestinationURL
        } catch {
            debugPrint("❌ FileProcessor: Failed to copy file: \(error)")
            throw AppError.fileReadFailed(filename: sourceURL.lastPathComponent, underlyingError: error)
        }
    }
    
    /// Calculate SHA256 hash of a file's content
    /// - Parameter url: The file URL to hash
    /// - Returns: SHA256 hash as a hex string
    /// - Throws: AppError if hashing fails
    public func calculateContentHash(for url: URL) async throws -> String {
        debugPrint("📄 FileProcessor: Calculating content hash for: \(url.lastPathComponent)")
        
        do {
            let data = try Data(contentsOf: url)
            let hash = SHA256.hash(data: data)
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
            debugPrint("✅ FileProcessor: Content hash calculated: \(hashString.prefix(16))...")
            return hashString
        } catch {
            debugPrint("❌ FileProcessor: Failed to calculate hash: \(error)")
            throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: error)
        }
    }
    
    /// Process an imported file: copy to Documents, calculate hash, and create Book
    /// - Parameters:
    ///   - sourceURL: The original file URL from document picker
    ///   - customTitle: Optional custom title for the book
    /// - Returns: A new Book instance with all metadata
    /// - Throws: AppError if processing fails
    public func processImportedFile(from sourceURL: URL, customTitle: String? = nil) async throws -> Book {
        debugPrint("📄 FileProcessor: Processing imported file: \(sourceURL.lastPathComponent)")
        
        // Step 1: Copy file to Documents directory
        let localFileURL = try await copyFileToDocuments(from: sourceURL)
        
        // Step 2: Calculate file size
        let fileSize = try getFileSize(for: localFileURL)
        
        // Step 3: Calculate content hash
        let contentHash = try await calculateContentHash(for: localFileURL)
        
        // Step 4: Create Book instance
        let title = customTitle ?? sourceURL.deletingPathExtension().lastPathComponent
        let book = Book(
            id: UUID(),
            title: title,
            fileURL: localFileURL,
            contentHash: contentHash,
            importedDate: Date(),
            fileSize: fileSize
        )
        
        debugPrint("✅ FileProcessor: Successfully processed imported file")
        debugPrint("📖 Book created: \(book.title) (\(book.fileSize) bytes)")
        
        return book
    }
    
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
    
    // MARK: - Private Helper Methods
    
    /// Get the app's Documents directory
    /// - Returns: URL of the Documents directory
    /// - Throws: AppError if Documents directory cannot be accessed
    private func getDocumentsDirectory() throws -> URL {
        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory, 
                                                                in: .userDomainMask, 
                                                                appropriateFor: nil, 
                                                                create: true)
            return documentsDirectory
        } catch {
            debugPrint("❌ FileProcessor: Failed to access Documents directory: \(error)")
            throw AppError.fileReadFailed(filename: "Documents", underlyingError: error)
        }
    }
    
    /// Generate a unique filename if the target file already exists
    /// - Parameter url: The desired file URL
    /// - Returns: A unique file URL (may be the same as input if no conflict)
    /// - Throws: AppError if file system operations fail
    private func generateUniqueFilename(for url: URL) throws -> URL {
        var uniqueURL = url
        var counter = 1
        
        while FileManager.default.fileExists(atPath: uniqueURL.path) {
            let filename = url.deletingPathExtension().lastPathComponent
            let fileExtension = url.pathExtension
            let uniqueFilename = "\(filename) (\(counter))"
            
            uniqueURL = url.deletingLastPathComponent()
                .appendingPathComponent(uniqueFilename)
                .appendingPathExtension(fileExtension)
            
            counter += 1
            
            // Safety check to prevent infinite loops
            if counter > 1000 {
                debugPrint("❌ FileProcessor: Too many filename conflicts, giving up")
                throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: nil)
            }
        }
        
        return uniqueURL
    }
    
    /// Get the file size for a given URL
    /// - Parameter url: The file URL
    /// - Returns: File size in bytes
    /// - Throws: AppError if file attributes cannot be read
    private func getFileSize(for url: URL) throws -> Int64 {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = fileAttributes[.size] as? Int64 else {
                throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: nil)
            }
            return fileSize
        } catch {
            debugPrint("❌ FileProcessor: Failed to get file size for: \(url.path) - \(error)")
            throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: error)
        }
    }
} 