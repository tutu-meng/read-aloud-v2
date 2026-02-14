//
//  LayoutMetrics.swift
//  ReadAloudApp
//

import CoreGraphics

/// Centralized layout metrics used for pagination and display
enum LayoutMetrics {
    /// Height reserved for bottom chrome (page indicator, etc.) in ReaderView
    static let chromeBottomHeight: CGFloat = 32
    /// Horizontal inset applied inside PageView's text container
    static let horizontalContentInset: CGFloat = 16
    /// Top inset applied inside PageView's text container
    static let verticalContentInsetTop: CGFloat = 16
    /// Bottom inset inside the UITextView text container (0 = text can reach the edge)
    static let verticalContentInsetBottom: CGFloat = 0
    /// Bottom margin reserved during pagination so each page has breathing room
    static let paginationBottomMargin: CGFloat = 30

    /// Compute the exact text drawable size for a given container size
    /// - Parameter container: The full container size from GeometryReader
    /// - Returns: The size available for actual text drawing within PageView
    static func computeTextDrawableSize(container: CGSize) -> CGSize {
        let drawableWidth = max(0, container.width - 2 * horizontalContentInset)
        let drawableHeight = max(0, container.height - chromeBottomHeight
                                   - verticalContentInsetTop - paginationBottomMargin)
        return CGSize(width: drawableWidth, height: drawableHeight)
    }
}
