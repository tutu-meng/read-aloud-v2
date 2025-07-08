# ReadAloudApp

A high-performance iOS application for reading large text files with text-to-speech capabilities.

## Requirements

- Xcode 16.0 or later
- iOS 17.0+ deployment target
- macOS with Xcode installed

## Running the App

### Method 1: Using the Xcode Project (Recommended)
```bash
# Open the project
open ReadAloudApp.xcodeproj

# Or regenerate if needed
xcodegen generate
open ReadAloudApp.xcodeproj
```

Then in Xcode:
1. Select a simulator (e.g., iPhone 15 Pro) from the device selector
2. Press ⌘+R or click the Run button
3. The app will build and launch in the simulator

### Method 2: Using Swift Package (for development)
```bash
# Open as Swift Package
open Package.swift
```

## Project Structure

```
ReadAloudApp/
├── Sources/ReadAloudApp/
│   ├── ReadAloudApp.swift          # App entry point
│   ├── Coordinators/               # Navigation logic
│   ├── Views/                      # SwiftUI views
│   ├── ViewModels/                 # Business logic
│   ├── Models/                     # Data models
│   ├── Services/                   # Business services
│   └── Resources/                  # Assets and Info.plist
├── Tests/                          # Unit tests
├── Package.swift                   # Swift Package definition
├── project.yml                     # XcodeGen configuration
└── ReadAloudApp.xcodeproj/        # Generated Xcode project
```

## Features

- **MVVM-C Architecture**: Clean separation of concerns
- **SwiftUI Interface**: Modern, declarative UI
- **Lazy Pagination**: Efficient memory usage for large files
- **Text-to-Speech**: Built-in reading functionality (coming soon)

## Current Status

- ✅ Project structure and architecture
- ✅ Basic navigation between screens
- ✅ Empty states and UI placeholders
- 🚧 File import functionality
- 🚧 Text pagination engine
- 🚧 Speech synthesis

## Troubleshooting

If the app doesn't run:
1. Make sure you have Xcode 16+ installed
2. Select an iOS 17+ simulator
3. Clean build folder (⌘+Shift+K) and rebuild
4. If project won't open, regenerate with: `xcodegen generate` 