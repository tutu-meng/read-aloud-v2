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
    
    /// Demonstration method showing bidirectional data flow
    func demonstrateInteroperability() {
        print("=== Swift/Objective-C Interoperability Test ===")
        
        let testText = "Hello from Swift!"
        
        // Call Objective-C method from Swift
        let processed = processWithLegacyCode(text: testText)
        print("Processed text: \(processed)")
        
        // Get hash from Objective-C
        let hash = calculateLegacyHash(text: testText)
        print("Legacy hash: \(hash)")
        
        // Demonstrate that Swift types work seamlessly
        let swiftArray = ["Swift", "Objective-C", "Interop"]
        for item in swiftArray {
            let result = legacyProcessor.processText(item)
            print("Processing '\(item)': \(result)")
        }
        
        print("=== Interoperability Test Complete ===")
    }
} 