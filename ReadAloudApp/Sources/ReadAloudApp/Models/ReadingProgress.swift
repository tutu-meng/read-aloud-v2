//
//  ReadingProgress.swift
//  ReadAloudApp
//
//  Created on 2024
//

import Foundation

/// ReadingProgress tracks the user's reading position within a book
struct ReadingProgress: Codable {
    /// The book's content hash (matches Book.contentHash) to identify the book
    let bookID: String
    
    /// The character index where the user last stopped reading
    var lastReadCharacterIndex: Int
    
    /// The last page number the user was on (optional, for UI convenience)
    var lastPageNumber: Int?
    
    /// The total number of pages (optional, for progress calculation)
    var totalPages: Int?
    
    /// The percentage of the book completed (0.0 to 1.0)
    var percentageComplete: Double?
    
    /// Last updated timestamp
    var lastUpdated: Date
    
    // MARK: - Initialization
    
    init(
        bookID: String,
        lastReadCharacterIndex: Int,
        lastPageNumber: Int? = nil,
        totalPages: Int? = nil,
        percentageComplete: Double? = nil,
        lastUpdated: Date = Date()
    ) {
        self.bookID = bookID
        self.lastReadCharacterIndex = lastReadCharacterIndex
        self.lastPageNumber = lastPageNumber
        self.totalPages = totalPages
        self.percentageComplete = percentageComplete
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Helper Methods

extension ReadingProgress {
    /// Create a new progress entry for a book starting from the beginning
    static func beginning(for bookID: String) -> ReadingProgress {
        return ReadingProgress(
            bookID: bookID,
            lastReadCharacterIndex: 0,
            lastPageNumber: 0,
            percentageComplete: 0.0
        )
    }
    
    /// Update the reading position
    mutating func updatePosition(
        characterIndex: Int,
        pageNumber: Int? = nil,
        totalPages: Int? = nil
    ) {
        self.lastReadCharacterIndex = characterIndex
        self.lastPageNumber = pageNumber
        self.totalPages = totalPages
        self.lastUpdated = Date()
        
        // Calculate percentage if we have total pages
        if let page = pageNumber, let total = totalPages, total > 0 {
            self.percentageComplete = Double(page) / Double(total)
        }
    }
    
    /// Check if the book has been started
    var hasBeenStarted: Bool {
        return lastReadCharacterIndex > 0 || (lastPageNumber ?? 0) > 0
    }
    
    /// Check if the book is likely completed (above 95%)
    var isNearlyComplete: Bool {
        return (percentageComplete ?? 0) > 0.95
    }
} 