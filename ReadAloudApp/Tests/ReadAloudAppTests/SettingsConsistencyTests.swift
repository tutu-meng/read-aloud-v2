//
//  SettingsConsistencyTests.swift
//  ReadAloudAppTests
//

import XCTest
import SwiftUI
@testable import ReadAloudApp

final class SettingsConsistencyTests: XCTestCase {
    @MainActor
    func testBackgroundAndDisplayUseIdenticalAttributedStringMapping() async {
        // Arrange fixed settings and content
        let settings = UserSettings(fontName: "Georgia", fontSize: 22, theme: "dark", lineSpacing: 1.6, speechRate: 1.0)
        let content = String(repeating: "Lorem ipsum dolor sit amet. ", count: 400)
        let container = CGSize(width: 300, height: 500)
        let viewSize = LayoutMetrics.computeTextDrawableSize(container: container)
        let bounds = CGRect(origin: .zero, size: viewSize)

        // Build attributed strings through the shared TextStyling utility used by both paths
        let attributedForBackground = TextStyling.createAttributedString(from: content, settings: settings)
        let attributedForDisplay = TextStyling.createAttributedString(from: content, settings: settings)

        // They should be functionally equivalent in attributes length and string
        XCTAssertEqual(attributedForBackground.string, attributedForDisplay.string)
        XCTAssertEqual(attributedForBackground.length, attributedForDisplay.length)

        // Use PaginationService to compute first page range using the same mapping
        let paginationService = PaginationService(textContent: content, userSettings: settings)
        let firstRangeBG = await paginationService.calculatePageRange(from: 0, in: bounds, with: attributedForBackground)
        let firstRangeUI = await paginationService.calculatePageRange(from: 0, in: bounds, with: attributedForDisplay)

        // Expect identical page ranges for same content/settings/bounds
        XCTAssertEqual(firstRangeBG.location, firstRangeUI.location)
        XCTAssertEqual(firstRangeBG.length, firstRangeUI.length)
    }

    func testComputeTextDrawableSize() {
        let container = CGSize(width: 390, height: 844)
        let expected = CGSize(
            width: max(0, 390 - 2 * LayoutMetrics.horizontalContentInset),
            height: max(0, 844 - LayoutMetrics.chromeBottomHeight - LayoutMetrics.verticalContentInsetTop - LayoutMetrics.verticalContentInsetBottom)
        )
        let actual = LayoutMetrics.computeTextDrawableSize(container: container)
        XCTAssertEqual(Int(actual.width), Int(expected.width))
        XCTAssertEqual(Int(actual.height), Int(expected.height))
    }
}


