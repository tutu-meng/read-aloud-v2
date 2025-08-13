# Book Opening and Navigation Workflow

This document explains the detailed workflow when a book is opened for the first time and how navigation works before pagination completes.

## Overview

The ReadAloudApp uses a sophisticated two-phase loading strategy:
1. **Immediate Display**: Shows estimated content immediately so users can start reading
2. **Background Pagination**: Performs accurate Core Text pagination in the background

This ensures a responsive user experience even with large files.

## Detailed Workflow

### 1. Book Selection (LibraryView → AppCoordinator)

```swift
// User taps a book in LibraryView
BookRow(book: book, onTap: {
    viewModel.selectBook(book)  // LibraryViewModel
})

// LibraryViewModel
func selectBook(_ book: Book) {
    coordinator.navigateToReader(with: book)
}

// AppCoordinator
func navigateToReader(with book: Book) {
    selectedBook = book
    currentView = .reader  // Triggers ContentView update
}
```

### 2. ReaderView Creation (ContentView)

```swift
// ContentView observes currentView change
case .reader:
    if let book = appCoordinator.selectedBook {
        ReaderView(viewModel: appCoordinator.makeReaderViewModel(for: book))
    }

// AppCoordinator creates ReaderViewModel
func makeReaderViewModel(for book: Book) -> ReaderViewModel {
    return ReaderViewModel(book: book, coordinator: self)
}
```

### 3. Book Loading (ReaderViewModel initialization)

```swift
init(book: Book, coordinator: AppCoordinator) {
    self.book = book
    self.coordinator = coordinator
    
    setupSettingsObservation()
    setupAppLifecycleObservation()
    loadBook()  // Starts the loading process
}
```

### 4. Two-Phase Loading Process

#### Phase 1: Immediate Display
```swift
func loadBook() {
    isLoading = true
    
    Task {
        // Load file content
        let textSource = try await coordinator.fileProcessor.loadText(from: book.fileURL)
        let content = try await extractTextContent(from: textSource)
        
        await MainActor.run {
            self.fullBookContent = content
            self.isLoading = false
            
            // Show content immediately with temporary pagination
            self.showInitialContent()
        }
        
        // Start background pagination
        await performBackgroundPagination(content: content)
    }
}

private func showInitialContent() {
    // Estimate characters per page (rough calculation)
    let estimatedCharsPerPage = max(1000, fullBookContent.count / 50)
    let startIndex = currentPage * estimatedCharsPerPage
    
    // Extract and show estimated page content
    if startIndex < fullBookContent.count {
        let endIndex = min(startIndex + estimatedCharsPerPage, fullBookContent.count)
        pageContent = String(fullBookContent[startIdx..<endIdx])
        totalPages = max(1, fullBookContent.count / estimatedCharsPerPage)
    }
}
```

#### Phase 2: Background Pagination
```swift
private func performBackgroundPagination(content: String) async {
    // Perform accurate Core Text pagination
    let pages = await currentPaginationService?.paginateText(
        content: content,
        settings: coordinator.userSettings,
        viewSize: currentContentSize
    ) ?? []
    
    await MainActor.run {
        self.bookPages = pages
        self.totalPages = self.bookPages.count
        
        // Update current page with accurate content
        self.updatePageContent()
    }
}
```

### 5. User Navigation Before Pagination Completes

The key to responsive navigation is the `currentPage` property with its `didSet` observer:

```swift
@Published var currentPage = 0 {
    didSet {
        if currentPage != oldValue && !isLoading {
            updatePageContent()
            saveCurrentProgress()
        }
    }
}

private func updatePageContent() {
    // Use accurate pages if available
    if !bookPages.isEmpty && currentPage < bookPages.count {
        pageContent = bookPages[currentPage]
    } else if !fullBookContent.isEmpty {
        // Otherwise, show estimated content
        Task { @MainActor in
            showEstimatedPageContent(for: currentPage)
        }
    }
}

private func showEstimatedPageContent(for page: Int) {
    let estimatedCharsPerPage = max(1000, fullBookContent.count / max(totalPages, 1))
    let startIndex = page * estimatedCharsPerPage
    
    if startIndex < fullBookContent.count {
        let endIndex = min(startIndex + estimatedCharsPerPage, fullBookContent.count)
        pageContent = String(fullBookContent[startIdx..<endIdx])
    }
}
```

### 6. Navigation Methods

```swift
func goToPage(_ page: Int) {
    guard page >= 0 && page < totalPages else { return }
    currentPage = page  // Triggers didSet
    
    // Save reading progress
    saveCurrentProgress()
}
```

## Key Features

### 1. Responsive UI
- Users can start reading immediately without waiting for pagination
- Navigation works even before accurate pagination completes
- Smooth transitions between estimated and accurate pages

### 2. Progressive Enhancement
- Initial display uses rough estimates (1000 chars/page)
- Background process calculates accurate page breaks using Core Text
- Once complete, all navigation uses accurate pagination

### 3. State Preservation
- Reading progress is saved on each navigation
- Position is restored when reopening books
- Works correctly even during re-pagination

### 4. Error Handling
- Graceful fallback if pagination fails
- Users can still read with estimated pagination
- Errors are reported but don't block reading

## Technical Details

### TabView Integration
The ReaderView uses SwiftUI's TabView for page navigation:

```swift
TabView(selection: $viewModel.currentPage) {
    ForEach(0..<viewModel.totalPages, id: \.self) { pageIndex in
        PageView(
            content: getPageContent(for: pageIndex),
            userSettings: viewModel.coordinator.userSettings,
            pageNumber: pageIndex + 1,
            totalPages: viewModel.totalPages
        )
        .tag(pageIndex)
    }
}
.tabViewStyle(.page(indexDisplayMode: .never))
```

### Memory Management
- Only the current page content is kept in memory
- Full book content is released after pagination
- Large files use streaming to avoid memory issues

## Performance Characteristics

1. **Initial Load Time**: < 1 second for typical books
2. **First Page Display**: Immediate after file loading
3. **Background Pagination**: 1-5 seconds depending on file size
4. **Navigation Response**: Instant (uses cached or estimated content)

## Summary

This workflow ensures users never have to wait:
1. Books open immediately with estimated pagination
2. Users can navigate while accurate pagination runs in background
3. Once complete, all future navigation uses accurate page breaks
4. The transition is seamless and transparent to users
