//
//  SettingsViewModel.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI
import Combine

/// SettingsViewModel manages the state and logic for the settings view
class SettingsViewModel: ObservableObject {
    // MARK: - Properties
    @Published var fontSize: Double = 16.0
    @Published var fontName: String = "System"
    @Published var theme: ColorTheme = .light
    @Published var speechRate: Double = 1.0
    @Published var lineSpacing: Double = 1.0
    
    private let coordinator: AppCoordinator
    
    // MARK: - Types
    enum ColorTheme: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case sepia = "Sepia"
    }
    
    // MARK: - Initialization
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        loadSettings()
    }
    
    // MARK: - Methods
    
    /// Load settings from storage
    func loadSettings() {
        // TODO: Load from UserSettings/PersistenceService
    }
    
    /// Save settings
    func saveSettings() {
        // TODO: Save using PersistenceService
        print("Saving settings")
    }
    
    /// Close settings
    func close() {
        saveSettings()
        coordinator.navigateToLibrary()
    }
} 