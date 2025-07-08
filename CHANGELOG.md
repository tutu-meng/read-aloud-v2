# Changelog

All notable changes to the ReadAloudApp project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - 2024

#### CORE-1: Initialize Xcode Project and Configure Basic Settings
- Created new Xcode project "ReadAloudApp" with SwiftUI interface and SwiftUI App lifecycle
- Set deployment target to iOS 17 (latest stable major version)
- Created MVVM-C architecture folder structure:
  - Coordinators: Contains AppCoordinator for navigation management
  - Views: Contains ContentView, LibraryView, ReaderView, and SettingsView
  - ViewModels: Contains LibraryViewModel, ReaderViewModel, and SettingsViewModel
  - Models: Contains Book model
  - Services: Placeholder for future service implementations
  - Resources: For app resources
- Created ReadAloudApp-Bridging-Header.h for Objective-C interoperability
- Implemented basic navigation flow using AppCoordinator pattern
- Created placeholder UI for all main screens
- Set up Swift Package Manager for dependency management
- Added unit test structure with basic Book model test

### Technical Details
- Used Swift Package structure that can be opened directly in Xcode
- Implemented ObservableObject pattern for ViewModels
- Used EnvironmentObject for AppCoordinator injection
- Created responsive SwiftUI layouts with proper navigation
- Generated Xcode project using XcodeGen for iOS Simulator support
- App can now be run in iOS Simulator with proper app target 