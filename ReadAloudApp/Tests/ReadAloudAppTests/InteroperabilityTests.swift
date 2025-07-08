//
//  InteroperabilityTests.swift
//  ReadAloudAppTests
//
//  Tests to verify Swift/Objective-C interoperability is working correctly.
//

import XCTest
@testable import ReadAloudApp

final class InteroperabilityTests: XCTestCase {
    
    var interopService: InteroperabilityService!
    
    override func setUp() {
        super.setUp()
        interopService = InteroperabilityService()
    }
    
    override func tearDown() {
        interopService = nil
        super.tearDown()
    }
    
    func testObjectiveCClassCanBeInstantiated() {
        // Direct test of Objective-C class from Swift
        let processor = LegacyTextProcessor()
        XCTAssertNotNil(processor, "Should be able to instantiate Objective-C class from Swift")
    }
    
    func testObjectiveCMethodsCanBeCalled() {
        // Test calling Objective-C instance methods
        let processor = LegacyTextProcessor()
        let testText = "Test String"
        
        let result = processor.processText(testText)
        XCTAssertTrue(result.contains(testText), "Processed text should contain original text")
        XCTAssertTrue(result.contains("Processed:"), "Processed text should contain processing marker")
    }
    
    func testInteroperabilityServiceProcessing() {
        // Test the Swift service that wraps Objective-C functionality
        let testText = "Hello, Interop!"
        let processed = interopService.processWithLegacyCode(text: testText)
        
        XCTAssertTrue(processed.contains(testText), "Processed text should contain input")
        XCTAssertTrue(processed.contains("[Processed:"), "Should include processing metadata")
    }
    
    func testInteroperabilityServiceHashing() {
        // Test hash calculation
        let testText = "Hash me!"
        let hash1 = interopService.calculateLegacyHash(text: testText)
        let hash2 = interopService.calculateLegacyHash(text: testText)
        
        XCTAssertEqual(hash1, hash2, "Same text should produce same hash")
        XCTAssertNotEqual(hash1, 0, "Hash should not be zero for non-empty text")
    }
    
    func testEmptyStringHandling() {
        // Test edge case handling
        let processed = interopService.processWithLegacyCode(text: "")
        XCTAssertEqual(processed, "[Empty Text]", "Empty text should be handled gracefully")
    }
    
    func testSwiftToObjectiveCTypeConversion() {
        // Test that Swift strings convert properly to NSString and back
        let swiftString = "Swift String with émojis 🎉"
        let processed = interopService.processWithLegacyCode(text: swiftString)
        
        XCTAssertTrue(processed.contains(swiftString), "Unicode should be preserved")
    }
} 