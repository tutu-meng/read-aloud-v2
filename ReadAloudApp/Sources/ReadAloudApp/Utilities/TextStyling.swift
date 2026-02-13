//
//  TextStyling.swift
//  ReadAloudApp
//
//  Shared text styling utilities used by both UI rendering (PageView)
//  and background pagination (BackgroundPaginationService, PaginationService).
//

import UIKit

enum TextStyling {
    /// Create an NSAttributedString with the given user settings applied.
    static func createAttributedString(from text: String, settings: UserSettings) -> NSAttributedString {
        let attrStr = NSMutableAttributedString(string: text)
        let font = resolveFont(name: settings.fontName, size: settings.fontSize)
        let color = textColor(for: settings.theme)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        attrStr.addAttribute(.font, value: font, range: fullRange)
        attrStr.addAttribute(.foregroundColor, value: color, range: fullRange)
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 4 * settings.lineSpacing
        ps.paragraphSpacing = 8 * settings.lineSpacing
        ps.lineBreakMode = .byCharWrapping
        attrStr.addAttribute(.paragraphStyle, value: ps, range: fullRange)
        return attrStr
    }

    static func resolveFont(name: String, size: CGFloat) -> UIFont {
        switch name {
        case "System": return UIFont.systemFont(ofSize: size)
        case "Georgia": return UIFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size)
        case "Helvetica": return UIFont(name: "Helvetica", size: size) ?? .systemFont(ofSize: size)
        case "Times New Roman": return UIFont(name: "Times New Roman", size: size) ?? .systemFont(ofSize: size)
        case "Courier": return UIFont(name: "Courier", size: size) ?? .systemFont(ofSize: size)
        case "Palatino": return UIFont(name: "Palatino-Roman", size: size) ?? .systemFont(ofSize: size)
        case "Baskerville": return UIFont(name: "Baskerville", size: size) ?? .systemFont(ofSize: size)
        default: return UIFont.systemFont(ofSize: size)
        }
    }

    static func textColor(for theme: String) -> UIColor {
        switch theme {
        case "dark": return .white
        case "sepia": return UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0)
        default: return .label
        }
    }

    static func backgroundColor(for theme: String) -> UIColor {
        switch theme {
        case "dark": return .black
        case "sepia": return UIColor(red: 0.95, green: 0.91, blue: 0.82, alpha: 1.0)
        default: return .systemBackground
        }
    }
}
