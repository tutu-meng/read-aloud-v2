//
//  PageView.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI
import UIKit

/// PageView displays a single page of content using UITextView for advanced text manipulation
/// This UIViewRepresentable wrapper provides access to UITextView's NSLayoutManager and NSTextStorage
/// which are essential for text-to-speech highlighting functionality
struct PageView: UIViewRepresentable {
    let content: String
    let pageIndex: Int
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        // Configure as read-only
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = true
        
        // Configure appearance
        textView.backgroundColor = UIColor.systemBackground
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = UIColor.label
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        // Configure text container
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.maximumNumberOfLines = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Create NSAttributedString with proper formatting
        let attributedString = createAttributedString(from: content)
        uiView.attributedText = attributedString
    }
    
    // MARK: - Private Methods
    
    private func createAttributedString(from text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        // Apply default styling
        let fullRange = NSRange(location: 0, length: text.count)
        attributedString.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        
        // Set paragraph style for better readability
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        
        return attributedString
    }
}

// MARK: - Preview
struct PageView_Previews: PreviewProvider {
    static var previews: some View {
        PageView(
            content: "This is a sample page content for preview.\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            pageIndex: 0
        )
        .previewLayout(.sizeThatFits)
    }
} 