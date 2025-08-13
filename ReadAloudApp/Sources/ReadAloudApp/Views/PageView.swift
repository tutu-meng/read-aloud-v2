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
public struct PageView: UIViewRepresentable {
    let content: String
    let pageIndex: Int
    
    // Access to shared user settings for font configuration
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    // MARK: - UIViewRepresentable
    
    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        
        // Configure as read-only
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = true
        
        // Configure appearance with user settings
        configureTextView(textView, with: appCoordinator.userSettings)
        
        return textView
    }
    
    public func updateUIView(_ uiView: UITextView, context: Context) {
        // Update appearance if settings changed
        configureTextView(uiView, with: appCoordinator.userSettings)
        
        // Create NSAttributedString with proper formatting
        let attributedString = createAttributedString(from: content, settings: appCoordinator.userSettings)
        uiView.attributedText = attributedString
    }
    
    func createAttributedString(from text: String, settings: UserSettings) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        // Get font based on settings
        let font = getFont(name: settings.fontName, size: settings.fontSize)
        let textColor = getTextColor(for: settings.theme)
        
        // Apply styling
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        attributedString.addAttribute(.font, value: font, range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: textColor, range: fullRange)
        
        // Set paragraph style for line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4 * settings.lineSpacing
        paragraphStyle.paragraphSpacing = 8 * settings.lineSpacing
        paragraphStyle.lineBreakMode = .byCharWrapping
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        
        return attributedString
    }
    
    /// Configure UITextView with user settings
    private func configureTextView(_ textView: UITextView, with settings: UserSettings) {
        // Configure appearance
        textView.backgroundColor = getBackgroundColor(for: settings.theme)
        textView.textColor = getTextColor(for: settings.theme)
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero
        if #available(iOS 11.0, *) {
            textView.contentInsetAdjustmentBehavior = .never
        }
        
        // Configure text container
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.maximumNumberOfLines = 0
        textView.textContainer.lineBreakMode = .byCharWrapping
    }
    
    /// Get UIFont based on font name and size
    private func getFont(name: String, size: CGFloat) -> UIFont {
        switch name {
        case "System":
            return UIFont.systemFont(ofSize: size)
        case "Georgia":
            return UIFont(name: "Georgia", size: size) ?? UIFont.systemFont(ofSize: size)
        case "Helvetica":
            return UIFont(name: "Helvetica", size: size) ?? UIFont.systemFont(ofSize: size)
        case "Times New Roman":
            return UIFont(name: "Times New Roman", size: size) ?? UIFont.systemFont(ofSize: size)
        case "Courier":
            return UIFont(name: "Courier", size: size) ?? UIFont.systemFont(ofSize: size)
        case "Palatino":
            return UIFont(name: "Palatino-Roman", size: size) ?? UIFont.systemFont(ofSize: size)
        case "Baskerville":
            return UIFont(name: "Baskerville", size: size) ?? UIFont.systemFont(ofSize: size)
        default:
            return UIFont.systemFont(ofSize: size)
        }
    }
    
    /// Get background color based on theme
    private func getBackgroundColor(for theme: String) -> UIColor {
        switch theme {
        case "dark":
            return UIColor.black
        case "sepia":
            return UIColor(red: 0.95, green: 0.91, blue: 0.82, alpha: 1.0)
        default:
            return UIColor.systemBackground
        }
    }
    
    /// Get text color based on theme
    private func getTextColor(for theme: String) -> UIColor {
        switch theme {
        case "dark":
            return UIColor.white
        case "sepia":
            return UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0)
        default:
            return UIColor.label
        }
    }
}

// MARK: - Preview
struct PageView_Previews: PreviewProvider {
    static var previews: some View {
        let coordinator = AppCoordinator()
        PageView(
            content: "This is a sample page content for preview.\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            pageIndex: 0
        )
        .environmentObject(coordinator)
        .previewLayout(.sizeThatFits)
    }
} 
