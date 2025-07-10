//
//  InteroperabilityService.swift
//  ReadAloudApp
//
//  This service demonstrates Swift/Objective-C interoperability by using
//  the LegacyTextProcessor Objective-C class from Swift code.
//

import Foundation

/// Service demonstrating Swift/Objective-C interoperability
class InteroperabilityService {
    
    // Using the Objective-C class directly in Swift
    private let legacyProcessor = LegacyTextProcessor()
    
    /// Process text using the legacy Objective-C processor
    /// - Parameter text: Input text to process
    /// - Returns: Processed text with metadata
    func processWithLegacyCode(text: String) -> String {
        // Direct call to Objective-C method
        return legacyProcessor.processText(text)
    }
    
    /// Calculate hash using the legacy algorithm
    /// - Parameter text: Input text
    /// - Returns: Hash value
    func calculateLegacyHash(text: String) -> UInt {
        // Direct call to Objective-C method returning NSUInteger
        return legacyProcessor.calculateHash(text)
    }
} 