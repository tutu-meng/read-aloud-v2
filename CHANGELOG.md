# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- CORE-1: Initialize Xcode Project and Configure Basic Settings
  - Created new Xcode project "ReadAloudApp" with SwiftUI interface and SwiftUI App lifecycle
  - Set iOS 17 deployment target
  - Implemented MVVM-C architecture with folder structure:
    - Coordinators (AppCoordinator for navigation)
    - Views (ContentView, LibraryView, ReaderView, SettingsView)
    - ViewModels (LibraryViewModel, ReaderViewModel, SettingsViewModel)
    - Models (Book model)
    - Services (placeholder)
    - Resources (Info.plist)
  - Created ReadAloudApp-Bridging-Header.h for Objective-C interoperability
  - Initially created as Swift Package, but couldn't run in simulator
  - Fixed by using XcodeGen to generate proper iOS app project with project.yml
  - All acceptance criteria met, app builds and runs in simulator

- CORE-2: Establish Swift/Objective-C Interoperability
  - Bridging header already created in CORE-1
  - Created demonstration Objective-C classes:
    - LegacyTextProcessor.h/.m with text processing and hashing methods
    - Shows C-style code integration
  - Created InteroperabilityService.swift demonstrating Swift calling Objective-C
  - Added comprehensive InteroperabilityTests.swift - 6 tests all passing
  - Updated AppCoordinator to include interoperabilityService
  - Verified build settings properly configured for bridging header

- CORE-3: Define Core Data Models
  - Book model already existed from CORE-1 with required properties
  - Created UserSettings model:
    - Properties: fontName, fontSize, theme, lineSpacing, speechRate
    - Conforms to Codable
    - Includes default values and static helper properties
  - Created ReadingProgress model:
    - Properties: bookID, lastReadCharacterIndex, plus optional tracking fields
    - Conforms to Codable
    - Helper methods for progress tracking
  - Updated SettingsViewModel to use UserSettings model instead of individual properties
  - Updated SettingsView bindings to work with UserSettings model
  - Created comprehensive ModelTests.swift - 12 tests all passing

- CORE-4: Implement Root AppCoordinator  
  - Enhanced existing AppCoordinator with MVVM-C pattern requirements:
    - Added `start()` method for application initialization
    - Added proper error handling with `handleError()` and auto-clearing
    - Added loading state management
    - Added app lifecycle observers (foreground/background)
    - Enhanced navigation methods with debug logging
    - Added deep link handling placeholder
    - Improved dependency injection through factory methods
  - Updated main app entry to call `start()` method on launch
  - Enhanced ContentView with error banner display and loading state
  - Created comprehensive AppCoordinatorTests.swift - 11 tests all passing
  - AppCoordinator now serves as the central navigation and dependency injection hub

- CORE-5: Implement Centralized Error Handling
  - Created AppError enum in new Utilities folder with domain-specific error cases
  - Implemented all required error cases plus additional ones for comprehensive coverage:
    - File operations: fileNotFound, fileReadFailed, fileTooLarge, invalidFileFormat
    - Text processing: paginationFailed, encodingError
    - Text-to-speech: ttsError, voiceNotAvailable, ttsNotSupported
    - Storage: saveFailed, loadFailed, insufficientStorage
    - Network: noNetworkConnection, downloadFailed
    - General: unknown, notImplemented
  - Full LocalizedError protocol conformance with user-friendly descriptions
  - Added error metadata: error codes, severity levels, recovery suggestions, help anchors
  - Integrated AppError with AppCoordinator for consistent error handling
  - Created comprehensive AppErrorTests.swift - 20 tests all passing
  - Total test count now at 50 (all passing)

### Fixed
- CORE-3-b: Fix UserSettings scope issue in SettingsViewModel
  - Xcode reported "cannot find UserSettings in scope" error in SettingsViewModel
  - Diagnosed missing imports in SettingsViewModel.swift
  - Added:
    - import Foundation
    - import CoreGraphics (needed for CGFloat type)
  - Cleaned DerivedData and regenerated Xcode project
  - Updated CHANGELOG to document the fix

### Changed
- Project converted from Swift Package to iOS app using XcodeGen
- Tests run via xcodebuild command line instead of swift test

### Technical Notes
- Using XcodeGen for project generation from project.yml
- Swift Package Manager for dependencies
- Git repository at code.corp.indeed.com:qsu/read-aloud-v2
- Project supports files up to 2GB with hybrid loading strategy planned
- Following MVVM-C pattern with AppCoordinator managing navigation

## [0.1.0] - Initial Setup
- Initial project creation
- Basic project structure
``` 