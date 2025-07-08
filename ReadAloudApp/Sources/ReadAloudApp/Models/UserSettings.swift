//
//  UserSettings.swift
//  ReadAloudApp
//
//  Created on 2024
//

import Foundation
import CoreGraphics

/// UserSettings holds all user-configurable settings for the reading experience
struct UserSettings: Codable {
    /// Font name for displaying text
    var fontName: String
    
    /// Font size for displaying text
    var fontSize: CGFloat
    
    /// Color theme (e.g., "light", "dark", "sepia")
    var theme: String
    
    /// Line spacing multiplier for text display
    var lineSpacing: CGFloat
    
    /// Speech rate for text-to-speech (1.0 = normal speed)
    var speechRate: Float
    
    // MARK: - Initialization
    
    /// Initialize with default values
    init(
        fontName: String = "System",
        fontSize: CGFloat = 16.0,
        theme: String = "light",
        lineSpacing: CGFloat = 1.2,
        speechRate: Float = 1.0
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.theme = theme
        self.lineSpacing = lineSpacing
        self.speechRate = speechRate
    }
}

// MARK: - Default Settings

extension UserSettings {
    /// Default settings for the app
    static let `default` = UserSettings()
    
    /// Available themes
    static let availableThemes = ["light", "dark", "sepia"]
    
    /// Available font names
    static let availableFonts = [
        "System",
        "Georgia",
        "Helvetica",
        "Times New Roman",
        "Courier",
        "Palatino",
        "Baskerville"
    ]
    
    /// Font size range
    static let fontSizeRange: ClosedRange<CGFloat> = 12.0...32.0
    
    /// Line spacing range
    static let lineSpacingRange: ClosedRange<CGFloat> = 0.8...2.0
    
    /// Speech rate range
    static let speechRateRange: ClosedRange<Float> = 0.5...2.0
} 