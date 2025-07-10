//
//  FileProcessor.swift
//  ReadAloudApp
//
//  Created on FILE-1 implementation
//  Enhanced for FILE-2: Memory-mapped file loading
//  Enhanced for FILE-3: Streaming file loading with NSFileHandle
//  Enhanced for PERSIST-2: File copying and hash calculation
//  Enhanced for FILE-7: Character encoding detection and override
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
    
    /// Process an imported file: copy to Documents, calculate hash, detect encoding, and create Book
    /// - Parameters:
    ///   - sourceURL: The original file URL from document picker
    ///   - customTitle: Optional custom title for the book
    /// - Returns: A new Book instance with all metadata including detected encoding
    /// - Throws: AppError if processing fails
    public func processImportedFile(from sourceURL: URL, customTitle: String? = nil) async throws -> Book {
        debugPrint("📄 FileProcessor: Processing imported file: \(sourceURL.lastPathComponent)")
        
        // Step 1: Copy file to Documents directory
        let localFileURL = try await copyFileToDocuments(from: sourceURL)
        
        // Step 2: Calculate file size
        let fileSize = try getFileSize(for: localFileURL)
        
        // Step 3: Calculate content hash
        let contentHash = try await calculateContentHash(for: localFileURL)
        
        // Step 4: Detect best encoding for the file
        let detectedEncoding = try await detectBestEncoding(for: localFileURL)
        debugPrint("📄 FileProcessor: Detected encoding: \(detectedEncoding)")
        
        // Step 5: Create Book instance with detected encoding
        let title = customTitle ?? sourceURL.deletingPathExtension().lastPathComponent
        let book = Book(
            id: UUID(),
            title: title,
            fileURL: localFileURL,
            contentHash: contentHash,
            importedDate: Date(),
            fileSize: fileSize,
            textEncoding: detectedEncoding
        )
        
        debugPrint("✅ FileProcessor: Successfully processed imported file")
        debugPrint("📖 Book created: \(book.title) (\(book.fileSize) bytes, encoding: \(book.textEncoding))")
        
        return book
    }
    
    /// Extract text content from a file using the specified encoding
    /// - Parameters:
    ///   - url: The file URL to read
    ///   - encoding: The text encoding to use
    /// - Returns: String content of the file
    /// - Throws: AppError if reading fails
    public func extractTextContent(from url: URL, using encoding: String.Encoding) async throws -> String {
        debugPrint("📄 FileProcessor: Extracting text content using encoding: \(encoding)")
        
        do {
            let data = try Data(contentsOf: url)
            guard let string = String(data: data, encoding: encoding) else {
                throw AppError.encodingError(filename: url.lastPathComponent)
            }
            debugPrint("✅ FileProcessor: Successfully extracted \(string.count) characters")
            return string
        } catch {
            debugPrint("❌ FileProcessor: Failed to extract text content: \(error)")
            if error is AppError {
                throw error
            } else {
                throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: error)
            }
        }
    }
    
    /// Extract text content from TextSource using the specified encoding
    /// - Parameters:
    ///   - textSource: The TextSource to read from
    ///   - encoding: The text encoding to use
    ///   - filename: Filename for error reporting
    /// - Returns: String content
    /// - Throws: AppError if extraction fails
    public func extractTextContent(from textSource: TextSource, using encoding: String.Encoding, filename: String) async throws -> String {
        debugPrint("📄 FileProcessor: Extracting text content from TextSource using encoding: \(encoding)")
        
        switch textSource {
        case .memoryMapped(let nsData):
            guard let string = String(data: nsData as Data, encoding: encoding) else {
                throw AppError.encodingError(filename: filename)
            }
            debugPrint("✅ FileProcessor: Successfully extracted \(string.count) characters from memory-mapped data")
            return string
            
        case .streaming(let fileHandle):
            let data = fileHandle.readDataToEndOfFile()
            guard let string = String(data: data, encoding: encoding) else {
                throw AppError.encodingError(filename: filename)
            }
            debugPrint("✅ FileProcessor: Successfully extracted \(string.count) characters from streaming data")
            return string
        }
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
    
    // MARK: - Encoding Detection Methods
    
    /// Detect the best encoding for a text file using a fallback chain
    /// - Parameter url: The file URL to analyze
    /// - Returns: The name of the best encoding found
    /// - Throws: AppError if file cannot be read
    public func detectBestEncoding(for url: URL) async throws -> String {
        debugPrint("🔍 FileProcessor: Detecting encoding for: \(url.lastPathComponent)")
        
        do {
            // Read a sample of the file for encoding detection (first 8KB should be enough)
            let sampleData = try Data(contentsOf: url).prefix(8192)
            
            // Try encodings in order of preference
            let encodingsToTry: [(String, String.Encoding)] = [
                ("UTF-8", .utf8),
                ("UTF-16", .utf16),
                ("ASCII", .ascii),
                ("ISO-8859-1", .isoLatin1),
                ("Windows-1252", .windowsCP1252),
                ("Shift_JIS", .shiftJIS),
                ("EUC-JP", .japaneseEUC)
            ]
            
            for (encodingName, encoding) in encodingsToTry {
                if let _ = String(data: sampleData, encoding: encoding) {
                    debugPrint("✅ FileProcessor: Successfully detected encoding: \(encodingName)")
                    return encodingName
                }
            }
            
            // If no encoding works, try more exotic ones
            let exoticEncodings: [(String, String.Encoding)] = [
                ("GBK", Book.stringEncoding(for: "GBK")),
                ("Big5", Book.stringEncoding(for: "Big5"))
            ]
            
            for (encodingName, encoding) in exoticEncodings {
                if let _ = String(data: sampleData, encoding: encoding) {
                    debugPrint("✅ FileProcessor: Successfully detected exotic encoding: \(encodingName)")
                    return encodingName
                }
            }
            
            // Last resort: default to UTF-8
            debugPrint("⚠️ FileProcessor: Could not detect encoding, defaulting to UTF-8")
            return "UTF-8"
            
        } catch {
            debugPrint("❌ FileProcessor: Failed to read file for encoding detection: \(error)")
            throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: error)
        }
    }
    
    /// Validate that a file can be properly decoded with the specified encoding
    /// - Parameters:
    ///   - url: The file URL to validate
    ///   - encoding: The encoding to test
    /// - Returns: True if the file can be decoded with the encoding
    public func validateEncoding(for url: URL, using encoding: String.Encoding) async -> Bool {
        debugPrint("🔍 FileProcessor: Validating encoding for: \(url.lastPathComponent)")
        
        do {
            // Read a sample of the file
            let sampleData = try Data(contentsOf: url).prefix(8192)
            
            // Try to decode with the specified encoding
            if let _ = String(data: sampleData, encoding: encoding) {
                debugPrint("✅ FileProcessor: Encoding validation successful")
                return true
            } else {
                debugPrint("❌ FileProcessor: Encoding validation failed")
                return false
            }
        } catch {
            debugPrint("❌ FileProcessor: Error during encoding validation: \(error)")
            return false
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