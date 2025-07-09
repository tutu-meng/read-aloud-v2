# Changelog

All notable changes to the ReadAloudApp project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### FILE-2: Memory-Mapped File Loading Strategy (2025-01-08)
- **Enhanced FileProcessor Service**: Implemented high-performance memory-mapped file loading using `NSData(contentsOfFile:options:.mappedIfSafe)`
- **Memory Mapping Strategy**: Delivers optimal performance for files under 1.5GB by leveraging macOS/iOS virtual memory system
- **Comprehensive Error Handling**: Added proper AppError integration with descriptive error messages
  - `AppError.fileNotFound(filename:)` for missing files
  - `AppError.fileReadFailed(filename:underlyingError:)` for read failures
  - Detailed logging for debugging and monitoring
- **Helper Methods**: Added utility methods for memory mapping threshold checking
  - `shouldUseMemoryMapping(for:)` - Size-based loading strategy determination
  - `getMemoryMapThreshold()` - Access to 1.5GB threshold constant
- **TextSource Enhancement**: Fully implemented TextSource.memoryMapped case with NSData integration
- **Comprehensive Testing**: Added 20 tests covering acceptance criteria, data integrity, and integration scenarios
  - FILE2MemoryMappingTests.swift with 10 specialized tests
  - Enhanced FileProcessorTests.swift with real file-based testing
  - 100% pass rate for all FILE-2 specific functionality

**Technical Benefits**:
- Zero-copy design with demand paging for memory efficiency
- OS-level optimization leveraging virtual memory system
- Instant file access without full load delays
- Scalable performance that doesn't degrade with file size
- Foundation for future hybrid loading strategy (streaming for files ≥ 1.5GB)

**Performance Characteristics**:
- Memory mapping threshold: 1.5GB (1,610,612,736 bytes)
- Supports Unicode content preservation
- Handles empty files and edge cases gracefully
- Comprehensive validation before file access attempts

#### UI-4: Real-time Settings Observation for Reader Interface (2025-01-08)
- **Shared UserSettings Architecture**: Established centralized settings management through AppCoordinator
- **PaginationService Integration**: Created intelligent caching system for efficient text re-pagination
- **Reactive Settings Observation**: Implemented Combine-based real-time settings monitoring in ReaderViewModel
- **Dynamic UI Updates**: Enhanced ReaderView and PageView with immediate visual feedback for settings changes
- **Comprehensive Testing**: Added 15 tests covering settings observation, cache management, and UI integration
- **Performance Optimization**: Intelligent caching prevents unnecessary re-calculations during settings updates

**User Experience Benefits**:
- Immediate visual feedback for font size, font family, and line spacing changes
- Smooth transitions during re-pagination without UI delays
- Proper accessibility support with real-time font scaling
- Theme support (light, dark, sepia) with appropriate contrast ratios
- Responsive design adapting to device orientation changes

**Technical Implementation**:
- Combine framework for reactive programming patterns
- SwiftUI environment object integration for shared state
- Font-aware pagination calculations with dynamic metrics
- Cache invalidation strategies for optimal performance
- Memory-efficient pagination with smart content management

### Changed

#### FILE-2: FileProcessor Service Evolution
- **Removed Placeholder Implementation**: Eliminated "notImplemented" error throwing from FILE-1
- **Enhanced API Surface**: Upgraded loadText method with production-ready memory mapping
- **Improved Error Context**: Enhanced error messages with filename and underlying error details
- **Robust Validation**: Added comprehensive file existence and URL validation
- **Performance Logging**: Integrated detailed debug logging for monitoring and troubleshooting

#### UI-4: Settings Architecture Refactoring
- **Centralized State Management**: Moved from local @Published properties to shared coordinator state
- **Reactive Data Flow**: Implemented publisher-subscriber pattern for settings propagation
- **View Size Tracking**: Added geometry reader integration for responsive pagination
- **Cache Management**: Introduced intelligent cache invalidation based on content and settings changes

### Fixed

#### FILE-2: Error Handling Improvements
- **AppError Parameter Compliance**: Fixed error calls to use correct parameter names (filename vs path)
- **Exception Handling**: Properly wrapped NSData initialization in try-catch blocks
- **Memory Safety**: Ensured proper error propagation without memory leaks
- **Test Reliability**: Enhanced test stability with proper temporary file cleanup

#### UI-4: Build and Runtime Fixes
- **Combine Complexity**: Simplified complex Combine expressions that caused compiler timeouts
- **Type Safety**: Resolved type inference issues in reactive chains
- **State Synchronization**: Fixed race conditions in settings observation lifecycle
- **UI Responsiveness**: Eliminated UI freezing during pagination operations

### Technical Details

#### FILE-2: Memory Mapping Architecture
```swift
// Core implementation pattern
do {
    let nsData = try NSData(contentsOfFile: url.path, options: .mappedIfSafe)
    return TextSource.memoryMapped(nsData)
} catch {
    throw AppError.fileReadFailed(filename: url.lastPathComponent, underlyingError: error)
}
```

#### UI-4: Settings Observation Pattern
```swift
// Reactive settings monitoring
coordinator.$userSettings
    .dropFirst()
    .sink { [weak self] settings in
        self?.handleSettingsChange(settings)
    }
```

### Documentation

#### FILE-2: Comprehensive Technical Documentation
- **Implementation Guide**: Complete FILE-2-complete.md with technical architecture details
- **Performance Analysis**: Memory mapping benefits and characteristics documentation
- **Error Handling**: Detailed error scenarios and recovery strategies
- **Testing Coverage**: Test categories and acceptance criteria verification
- **Future Considerations**: Hybrid loading strategy foundation documentation

#### UI-4: User Experience Documentation
- **Feature Overview**: UI-4-complete.md with implementation details and user benefits
- **Technical Architecture**: Mermaid diagrams illustrating reactive data flow
- **Performance Metrics**: Caching strategy and optimization benefits
- **Accessibility**: Real-time font scaling and theme support documentation
- **Integration Guide**: Settings observation patterns and best practices

### Dependencies

#### FILE-2: System Requirements
- iOS 17.0+ for memory mapping APIs
- Foundation framework for NSData operations
- Proper file system permissions for memory mapping

#### UI-4: Framework Dependencies
- Combine framework for reactive programming
- SwiftUI for declarative UI updates
- Core Graphics for font metrics calculations

---

## Previous Releases

### [1.0.0] - 2025-01-07
- Initial project structure and core architecture
- FILE-1: Basic FileProcessor and TextSource abstraction
- UI-1, UI-2, UI-3: Core UI components and navigation
- Comprehensive test suite foundation
- MVVM-C architecture establishment 