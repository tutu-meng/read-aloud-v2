//
//  SettingsViewModel.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI
import Combine
import Foundation
import CoreGraphics

/// SettingsViewModel manages the state and logic for the settings view
class SettingsViewModel: ObservableObject {
    // MARK: - Properties
    @Published var userSettings: UserSettings = .default
    
    private let coordinator: AppCoordinator
    
    // MARK: - Types
    enum ColorTheme: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case sepia = "Sepia"
        
        var themeString: String {
            return self.rawValue.lowercased()
        }
        
        init(from theme: String) {
            switch theme.lowercased() {
            case "dark": self = .dark
            case "sepia": self = .sepia
            default: self = .light
            }
        }
    }
    
    // MARK: - Initialization
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        loadSettings()
    }
    
    // MARK: - Methods
    
    /// Load settings from storage
    func loadSettings() {
        // TODO: Load from PersistenceService
        // For now, using default settings
        self.userSettings = UserSettings.default
    }
    
    /// Save settings
    func saveSettings() {
        // TODO: Save using PersistenceService
        print("Saving settings: \(userSettings)")
    }
    
    /// Close settings
    func close() {
        saveSettings()
        coordinator.navigateToLibrary()
    }
} 