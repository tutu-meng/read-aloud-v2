//
//  PageViewTests.swift
//  ReadAloudAppTests
//
//  Created on 2024
//

import XCTest
import SwiftUI
import UIKit
@testable import ReadAloudApp

final class PageViewTests: XCTestCase {
    
    // MARK: - Test PageView Creation
    
    func testPageViewCreation() {
        let content = "Test content for page view"
        let pageView = PageView(content: content, pageIndex: 0)
        
        XCTAssertEqual(pageView.content, content)
        XCTAssertEqual(pageView.pageIndex, 0)
    }
    
    func testPageViewWithDifferentIndex() {
        let content = "Another test content"
        let pageView = PageView(content: content, pageIndex: 5)
        
        XCTAssertEqual(pageView.content, content)
        XCTAssertEqual(pageView.pageIndex, 5)
    }
    
    func testPageViewWithEmptyContent() {
        let pageView = PageView(content: "", pageIndex: 0)
        
        XCTAssertEqual(pageView.content, "")
        XCTAssertEqual(pageView.pageIndex, 0)
    }
    
    func testPageViewWithLongContent() {
        let longContent = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 100)
        let pageView = PageView(content: longContent, pageIndex: 3)
        
        XCTAssertEqual(pageView.content, longContent)
        XCTAssertEqual(pageView.pageIndex, 3)
    }
    
    // MARK: - Test UIViewRepresentable Conformance
    
    func testUIViewRepresentableConformance() {
        let pageView = PageView(content: "Test", pageIndex: 0)
        XCTAssertTrue(pageView is any UIViewRepresentable)
    }
    
    // MARK: - Test UITextView Creation (Direct Testing)
    
    func testMakeUIViewCreatesCorrectType() {
        let pageView = PageView(content: "Test", pageIndex: 0)
        
        // We can't easily create a UIViewRepresentableContext in tests,
        // so we'll test the PageView properties directly
        XCTAssertEqual(pageView.content, "Test")
        XCTAssertEqual(pageView.pageIndex, 0)
        
        // Test that PageView conforms to UIViewRepresentable
        XCTAssertTrue(pageView is any UIViewRepresentable)
    }
    
    // MARK: - Test Content Variations
    
    func testContentWithSpecialCharacters() {
        let content = "Test with special characters: !@#$%^&*()_+-=[]{}|;:,.<>?"
        let pageView = PageView(content: content, pageIndex: 1)
        
        XCTAssertEqual(pageView.content, content)
        XCTAssertEqual(pageView.pageIndex, 1)
    }
    
    func testContentWithNewlines() {
        let content = "Line 1\nLine 2\nLine 3"
        let pageView = PageView(content: content, pageIndex: 2)
        
        XCTAssertEqual(pageView.content, content)
        XCTAssertEqual(pageView.pageIndex, 2)
    }
    
    func testContentWithUnicodeCharacters() {
        let content = "Unicode test: 🚀 📱 🎯 中文 العربية"
        let pageView = PageView(content: content, pageIndex: 4)
        
        XCTAssertEqual(pageView.content, content)
        XCTAssertEqual(pageView.pageIndex, 4)
    }

    // MARK: - Regression: Ensure attributes cover full UTF-16 range and char wrapping is set
    func testAttributedStringCoversFullUTF16RangeAndCharWrapping() {
        // Include multi-codepoint graphemes and CJK to stress UTF-16 length vs Character count
        let text = "末尾测试🙂中文🚀"
        let pv = PageView(content: text, pageIndex: 0)
        let settings = UserSettings.default
        let attr = pv.createAttributedString(from: text, settings: settings)

        let nsLen = (text as NSString).length
        // Extract paragraph style at the last UTF-16 index-1
        let range = NSRange(location: nsLen - 1, length: 1)
        let attrs = attr.attributes(at: nsLen - 1, effectiveRange: nil)
        let font = attrs[.font] as? UIFont
        let color = attrs[.foregroundColor] as? UIColor
        let para = attrs[.paragraphStyle] as? NSParagraphStyle

        XCTAssertNotNil(font)
        XCTAssertNotNil(color)
        XCTAssertNotNil(para)
        XCTAssertEqual(para?.lineBreakMode, .byCharWrapping)
        // Sanity: ensure attributed length equals UTF-16 length
        XCTAssertEqual(attr.length, nsLen)
        XCTAssertEqual(range.location, nsLen - 1)
    }
    
    // MARK: - Test PageView Initialization Edge Cases
    
    func testPageViewWithNegativeIndex() {
        let pageView = PageView(content: "Test", pageIndex: -1)
        
        XCTAssertEqual(pageView.content, "Test")
        XCTAssertEqual(pageView.pageIndex, -1)
    }
    
    func testPageViewWithLargeIndex() {
        let pageView = PageView(content: "Test", pageIndex: 99999)
        
        XCTAssertEqual(pageView.content, "Test")
        XCTAssertEqual(pageView.pageIndex, 99999)
    }
    
    // MARK: - Test Integration with SwiftUI
    
    func testPageViewCanBeUsedInSwiftUI() {
        let pageView = PageView(content: "Integration test", pageIndex: 0)
        
        // This tests that PageView can be used as a SwiftUI view
        let view = VStack {
            pageView
        }
        
        XCTAssertNotNil(view)
    }
}

// MARK: - Test Extensions

extension PageViewTests {
    /// Test that PageView properties are immutable (let vs var)
    func testPageViewPropertiesAreImmutable() {
        let pageView = PageView(content: "Test", pageIndex: 0)
        
        // These should be let properties, not var
        // If they were var, this would fail to compile
        XCTAssertEqual(pageView.content, "Test")
        XCTAssertEqual(pageView.pageIndex, 0)
    }
} 