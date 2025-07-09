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
    
    /// Access to shared UserSettings through coordinator
    var userSettings: UserSettings {
        get { coordinator.userSettings }
        set { coordinator.userSettings = newValue }
    }
    
    private let coordinator: AppCoordinator
    private var cancellables = Set<AnyCancellable>()
    
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
        setupObservation()
        loadSettings()
    }
    
    // MARK: - Observation Setup
    
    /// Set up observation of coordinator's UserSettings
    private func setupObservation() {
        // Forward changes from coordinator's userSettings to trigger UI updates
        coordinator.$userSettings
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Methods
    
    /// Load settings from storage
    func loadSettings() {
        // TODO: Load from PersistenceService
        // For now, using default settings in coordinator
        if coordinator.userSettings.fontName == "System" {
            debugPrint("⚙️ SettingsViewModel: Using default settings")
        } else {
            debugPrint("⚙️ SettingsViewModel: Loaded existing settings")
        }
    }
    
    /// Save settings
    func saveSettings() {
        // TODO: Save using PersistenceService
        debugPrint("⚙️ SettingsViewModel: Saving settings: \(userSettings)")
    }
    
    /// Save settings without navigation (for sheet dismissal)
    func saveSettingsOnly() {
        saveSettings()
    }
    
    /// Close settings
    func close() {
        saveSettings()
        coordinator.navigateToLibrary()
    }
} 