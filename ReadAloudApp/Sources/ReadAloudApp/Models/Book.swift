//
//  Book.swift
//  ReadAloudApp
//
//  Created on 2024
//

import Foundation

/// Book represents an imported text file in the app
public struct Book: Identifiable, Codable, Hashable {
    /// Unique identifier for the book
    public let id: UUID
    
    /// Title of the book (derived from filename)
    public let title: String
    
    /// URL to the file in the app's sandbox
    public let fileURL: URL
    
    /// SHA256 hash of the file content (used as canonical identifier)
    public let contentHash: String
    
    /// Date when the book was imported
    public let importedDate: Date
    
    /// File size in bytes
    public let fileSize: Int64
    
    /// Text encoding used for this book (defaults to UTF-8)
    public let textEncoding: String
    
    // MARK: - Initialization
    
    public init(id: UUID = UUID(), 
         title: String, 
         fileURL: URL, 
         contentHash: String,
         importedDate: Date = Date(),
         fileSize: Int64 = 0,
         textEncoding: String = "UTF-8") {
        self.id = id
        self.title = title
        self.fileURL = fileURL
        self.contentHash = contentHash
        self.importedDate = importedDate
        self.fileSize = fileSize
        self.textEncoding = textEncoding
    }
    
    // MARK: - Encoding Support
    
    /// Get the String.Encoding for this book's text encoding
    public var stringEncoding: String.Encoding {
        return Book.stringEncoding(for: textEncoding)
    }
    
    /// Convert encoding name to String.Encoding
    public static func stringEncoding(for encodingName: String) -> String.Encoding {
        switch encodingName.uppercased() {
        case "UTF-8":
            return .utf8
        case "UTF-16":
            return .utf16
        case "UTF-32":
            return .utf32
        case "ASCII":
            return .ascii
        case "ISO-8859-1", "LATIN-1":
            return .isoLatin1
        case "WINDOWS-1252", "CP1252":
            return .windowsCP1252
        case "SHIFT_JIS", "SHIFT-JIS":
            return .shiftJIS
        case "EUC-JP":
            return .japaneseEUC
        case "GBK", "GB18030":
            return .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        case "BIG5":
            return .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
        default:
            return .utf8 // Default fallback
        }
    }
} 