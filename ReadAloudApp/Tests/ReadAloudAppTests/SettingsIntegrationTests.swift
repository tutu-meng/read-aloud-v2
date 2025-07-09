//
//  SettingsIntegrationTests.swift
//  ReadAloudAppTests
//
//  Created on 2024
//

import XCTest
import SwiftUI
@testable import ReadAloudApp

final class SettingsIntegrationTests: XCTestCase {
    
    var coordinator: AppCoordinator!
    var book: Book!
    
    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
        book = Book(
            title: "Test Book",
            fileURL: URL(fileURLWithPath: "/test/path"),
            contentHash: "test-hash",
            importedDate: Date(),
            fileSize: 1000
        )
    }
    
    override func tearDown() {
        coordinator = nil
        book = nil
        super.tearDown()
    }
    
    // MARK: - ReaderViewModel Settings Integration Tests
    
    func testReaderViewModelCanCreateSettingsViewModel() {
        let readerViewModel = ReaderViewModel(book: book, coordinator: coordinator)
        
        let settingsViewModel = readerViewModel.makeSettingsViewModel()
        
        XCTAssertNotNil(settingsViewModel)
        XCTAssertEqual(settingsViewModel.userSettings.fontName, "System")
        XCTAssertEqual(settingsViewModel.userSettings.fontSize, 16.0)
        XCTAssertEqual(settingsViewModel.userSettings.theme, "light")
    }
    
    func testReaderViewModelSettingsViewModelIndependence() {
        let readerViewModel = ReaderViewModel(book: book, coordinator: coordinator)
        
        let settingsViewModel1 = readerViewModel.makeSettingsViewModel()
        let settingsViewModel2 = readerViewModel.makeSettingsViewModel()
        
        // Should create separate instances
        XCTAssertFalse(settingsViewModel1 === settingsViewModel2)
        
        // But should have the same initial settings
        XCTAssertEqual(settingsViewModel1.userSettings.fontName, settingsViewModel2.userSettings.fontName)
        XCTAssertEqual(settingsViewModel1.userSettings.fontSize, settingsViewModel2.userSettings.fontSize)
    }
    
    // MARK: - SettingsView Integration Tests
    
    func testSettingsViewInitializationWithSheetMode() {
        let settingsViewModel = SettingsViewModel(coordinator: coordinator)
        
        let settingsViewSheet = SettingsView(viewModel: settingsViewModel, isSheet: true)
        let settingsViewFull = SettingsView(viewModel: settingsViewModel, isSheet: false)
        
        XCTAssertTrue(settingsViewSheet.isSheet)
        XCTAssertFalse(settingsViewFull.isSheet)
    }
    
    func testSettingsViewDefaultInitialization() {
        let settingsViewModel = SettingsViewModel(coordinator: coordinator)
        
        let settingsView = SettingsView(viewModel: settingsViewModel)
        
        XCTAssertFalse(settingsView.isSheet, "Default should be false for full-screen mode")
    }
    
    // MARK: - SettingsViewModel Behavior Tests
    
    func testSettingsViewModelSaveSettingsOnly() {
        let settingsViewModel = SettingsViewModel(coordinator: coordinator)
        
        // Modify some settings
        settingsViewModel.userSettings.fontSize = 20.0
        settingsViewModel.userSettings.theme = "dark"
        
        // This should save without navigation
        settingsViewModel.saveSettingsOnly()
        
        // Verify coordinator state hasn't changed (no navigation occurred)
        XCTAssertEqual(coordinator.currentView, .library)
    }
    
    func testSettingsViewModelCloseNavigatesToLibrary() {
        let settingsViewModel = SettingsViewModel(coordinator: coordinator)
        
        // Start from a different view
        coordinator.currentView = .reader
        
        // Modify some settings
        settingsViewModel.userSettings.fontSize = 18.0
        
        // This should save and navigate
        settingsViewModel.close()
        
        // Verify navigation occurred
        XCTAssertEqual(coordinator.currentView, .library)
    }
    
    // MARK: - UserSettings Validation Tests
    
    func testUserSettingsRangeValidation() {
        let settingsViewModel = SettingsViewModel(coordinator: coordinator)
        
        // Test font size range
        XCTAssertTrue(UserSettings.fontSizeRange.contains(12.0))
        XCTAssertTrue(UserSettings.fontSizeRange.contains(32.0))
        XCTAssertFalse(UserSettings.fontSizeRange.contains(10.0))
        XCTAssertFalse(UserSettings.fontSizeRange.contains(40.0))
        
        // Test line spacing range
        XCTAssertTrue(UserSettings.lineSpacingRange.contains(0.8))
        XCTAssertTrue(UserSettings.lineSpacingRange.contains(2.0))
        XCTAssertFalse(UserSettings.lineSpacingRange.contains(0.5))
        XCTAssertFalse(UserSettings.lineSpacingRange.contains(3.0))
        
        // Test speech rate range
        XCTAssertTrue(UserSettings.speechRateRange.contains(0.5))
        XCTAssertTrue(UserSettings.speechRateRange.contains(2.0))
        XCTAssertFalse(UserSettings.speechRateRange.contains(0.3))
        XCTAssertFalse(UserSettings.speechRateRange.contains(3.0))
    }
    
    func testUserSettingsAvailableOptions() {
        // Test available fonts
        XCTAssertTrue(UserSettings.availableFonts.contains("System"))
        XCTAssertTrue(UserSettings.availableFonts.contains("Georgia"))
        XCTAssertTrue(UserSettings.availableFonts.contains("Helvetica"))
        XCTAssertFalse(UserSettings.availableFonts.isEmpty)
        
        // Test available themes
        XCTAssertTrue(UserSettings.availableThemes.contains("light"))
        XCTAssertTrue(UserSettings.availableThemes.contains("dark"))
        XCTAssertTrue(UserSettings.availableThemes.contains("sepia"))
        XCTAssertFalse(UserSettings.availableThemes.isEmpty)
    }
    
    // MARK: - ColorTheme Enum Tests
    
    func testColorThemeEnumMapping() {
        let lightTheme = SettingsViewModel.ColorTheme(from: "light")
        let darkTheme = SettingsViewModel.ColorTheme(from: "dark")
        let sepiaTheme = SettingsViewModel.ColorTheme(from: "sepia")
        let unknownTheme = SettingsViewModel.ColorTheme(from: "unknown")
        
        XCTAssertEqual(lightTheme, .light)
        XCTAssertEqual(darkTheme, .dark)
        XCTAssertEqual(sepiaTheme, .sepia)
        XCTAssertEqual(unknownTheme, .light) // Should default to light
        
        // Test string conversion
        XCTAssertEqual(lightTheme.themeString, "light")
        XCTAssertEqual(darkTheme.themeString, "dark")
        XCTAssertEqual(sepiaTheme.themeString, "sepia")
    }
    
    func testColorThemeAllCases() {
        let allCases = SettingsViewModel.ColorTheme.allCases
        
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.light))
        XCTAssertTrue(allCases.contains(.dark))
        XCTAssertTrue(allCases.contains(.sepia))
    }
    
    // MARK: - Settings Persistence Tests
    
    func testSettingsViewModelLoadsDefaultSettings() {
        let settingsViewModel = SettingsViewModel(coordinator: coordinator)
        
        // Should load default settings
        XCTAssertEqual(settingsViewModel.userSettings.fontName, "System")
        XCTAssertEqual(settingsViewModel.userSettings.fontSize, 16.0)
        XCTAssertEqual(settingsViewModel.userSettings.theme, "light")
        XCTAssertEqual(settingsViewModel.userSettings.lineSpacing, 1.2)
        XCTAssertEqual(settingsViewModel.userSettings.speechRate, 1.0)
    }
    
    func testSettingsViewModelModification() {
        let settingsViewModel = SettingsViewModel(coordinator: coordinator)
        
        // Modify settings
        settingsViewModel.userSettings.fontName = "Georgia"
        settingsViewModel.userSettings.fontSize = 24.0
        settingsViewModel.userSettings.theme = "dark"
        settingsViewModel.userSettings.lineSpacing = 1.5
        settingsViewModel.userSettings.speechRate = 1.2
        
        // Verify changes
        XCTAssertEqual(settingsViewModel.userSettings.fontName, "Georgia")
        XCTAssertEqual(settingsViewModel.userSettings.fontSize, 24.0)
        XCTAssertEqual(settingsViewModel.userSettings.theme, "dark")
        XCTAssertEqual(settingsViewModel.userSettings.lineSpacing, 1.5)
        XCTAssertEqual(settingsViewModel.userSettings.speechRate, 1.2)
    }
} 