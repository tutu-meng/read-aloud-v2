//
//  Book.swift
//  ReadAloudApp
//
//  Created on 2024
//

import Foundation

/// Book represents an imported text file in the app
struct Book: Identifiable, Codable, Hashable {
    /// Unique identifier for the book
    let id: UUID
    
    /// Title of the book (derived from filename)
    let title: String
    
    /// URL to the file in the app's sandbox
    let fileURL: URL
    
    /// SHA256 hash of the file content (used as canonical identifier)
    let contentHash: String
    
    /// Date when the book was imported
    let importedDate: Date
    
    /// File size in bytes
    let fileSize: Int64
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(), 
         title: String, 
         fileURL: URL, 
         contentHash: String,
         importedDate: Date = Date(),
         fileSize: Int64 = 0) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
        self.contentHash = contentHash
        self.importedDate = importedDate
        self.fileSize = fileSize
    }
} 