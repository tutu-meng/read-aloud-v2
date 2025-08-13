# PGN-6 Fix Plan: Page Navigation Reload Bug

## Root Cause Analysis

After analyzing the code, I've identified the exact cause of the bug:

1. **ContentView recreates ReaderViewModel on every render**
   - Line 21: `ReaderView(viewModel: appCoordinator.makeReaderViewModel(for: book))`
   - `makeReaderViewModel()` creates a NEW instance every time
   - Any state change in AppCoordinator triggers ContentView re-render
   - This causes ReaderViewModel to be recreated, restarting `loadBook()`

2. **ReaderView uses @ObservedObject instead of @StateObject**
   - Line 12: `@ObservedObject var viewModel: ReaderViewModel`
   - @ObservedObject doesn't retain the view model
   - Combined with #1, this allows the view model to be destroyed and recreated

## Fix Implementation

### Option 1: Cache ReaderViewModel in AppCoordinator (Recommended)

**Step 1: Add caching to AppCoordinator**
```swift
// AppCoordinator.swift
class AppCoordinator: ObservableObject {
    // Add this property
    private var cachedReaderViewModel: ReaderViewModel?
    
    // Modify makeReaderViewModel
    func makeReaderViewModel(for book: Book) -> ReaderViewModel {
        // Check if we already have a view model for this book
        if let cached = cachedReaderViewModel, 
           cached.book.id == book.id {
            debugPrint("🏭 AppCoordinator: Returning cached ReaderViewModel for book: \(book.title)")
            return cached
        }
        
        // Create new view model and cache it
        debugPrint("🏭 AppCoordinator: Creating new ReaderViewModel for book: \(book.title)")
        let viewModel = ReaderViewModel(book: book, coordinator: self)
        cachedReaderViewModel = viewModel
        return viewModel
    }
    
    // Clear cache when leaving reader
    func navigateToLibrary() {
        debugPrint("📚 AppCoordinator: Navigating to library")
        currentView = .library
        selectedBook = nil
        cachedReaderViewModel = nil  // Clear the cache
    }
    
    // Also handle navigation to reader with different book
    func navigateToReader(with book: Book) {
        // Clear cache if switching to a different book
        if let cached = cachedReaderViewModel, 
           cached.book.id != book.id {
            debugPrint("♻️ AppCoordinator: Clearing cache for book switch")
            cachedReaderViewModel = nil
        }
        
        selectedBook = book
        currentView = .reader
    }
}
```

**Step 2: Update ReaderView to use @StateObject (defensive)**
```swift
// ReaderView.swift
struct ReaderView: View {
    @StateObject var viewModel: ReaderViewModel  // Change from @ObservedObject
    
    // Add custom init if needed
    init(viewModel: ReaderViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
}
```

### Option 2: Move ViewModel Creation to View Level

**Alternative approach using @StateObject directly:**
```swift
// ContentView.swift
case .reader:
    if let book = appCoordinator.selectedBook {
        ReaderViewWrapper(book: book, coordinator: appCoordinator)
    }

// New wrapper view
struct ReaderViewWrapper: View {
    let book: Book
    let coordinator: AppCoordinator
    @StateObject private var viewModel: ReaderViewModel
    
    init(book: Book, coordinator: AppCoordinator) {
        self.book = book
        self.coordinator = coordinator
        self._viewModel = StateObject(wrappedValue: ReaderViewModel(book: book, coordinator: coordinator))
    }
    
    var body: some View {
        ReaderView(viewModel: viewModel)
    }
}
```

## Why Option 1 is Better

1. **Single Source of Truth**: AppCoordinator manages all view models
2. **State Preservation**: ViewModel survives parent view updates
3. **Memory Management**: Clear lifecycle (created on navigation, destroyed on exit)
4. **Minimal Changes**: Only requires changes to AppCoordinator and minor ReaderView update
5. **Consistent Pattern**: Matches existing architecture

## Important Scenarios to Handle

### 1. Book Close and Reopen
When user closes a book and reopens it:
- **Expected**: Load saved reading progress from persistence
- **Challenge**: Cached instance might have different page than saved progress
- **Solution**: Clear cache when leaving reader to ensure fresh load

### 2. Switching Between Books
When user has Book A open, goes to library, opens Book B:
- **Expected**: Book B starts fresh (not using Book A's view model)
- **Solution**: Check book ID in cache, only reuse if same book

### 3. Cache Lifecycle
- **Create cache**: When navigating to reader
- **Use cache**: During the reading session (prevents reload bug)
- **Clear cache**: When navigating away from reader
- **Result**: Each reading session starts fresh with saved progress

## Testing the Fix

1. **Primary Test (Bug Fix)**:
   - Open a book
   - Immediately swipe to page 2
   - Verify: Page 2 content shows (not page 1)
   - Verify: No reload or view recreation

2. **State Preservation Test**:
   - Open a book, navigate to page 5
   - Trigger AppCoordinator state change (e.g., error message)
   - Verify: Still on page 5, no reload

3. **Book Reopen Test**:
   - Open book A, navigate to page 10
   - Go back to library
   - Reopen book A
   - Verify: Loads saved progress (not cached page 10)

4. **Book Switch Test**:
   - Open book A, navigate around
   - Go back to library
   - Open book B
   - Verify: New ReaderViewModel created (not reusing book A's)

5. **Memory Test**:
   - Open and close multiple books
   - Verify: No memory leaks, cache properly cleared

## Implementation Steps

1. Add `cachedReaderViewModel` property to AppCoordinator
2. Modify `makeReaderViewModel()` to check cache first
3. Clear cache in `navigateToLibrary()`
4. Update ReaderView to use @StateObject (defensive)
5. Test thoroughly

## Expected Result

- Navigation during pagination works correctly
- No page reloads or resets
- State preserved during parent view updates
- Clean memory management

## Detailed Behavior After Fix

### During Reading Session
1. **User opens book** → New ReaderViewModel created, cached, loads saved progress
2. **User navigates pages** → Uses cached instance, no reloads
3. **Any AppCoordinator state changes** → Still uses cached instance, no reloads
4. **User can navigate freely** → Page changes work immediately, even during pagination

### When Leaving Reader
1. **User taps "Library" button** → Cache cleared, ViewModel properly disposed
2. **User opens Settings from reader** → Cache retained (still in reading session)
3. **App goes to background** → Cache retained, progress saved

### When Reopening Book
1. **User reopens same book** → New instance created, loads saved progress from persistence
2. **User opens different book** → New instance created, old cache cleared if exists

This ensures:
- The navigation bug is fixed (no reloads during reading)
- Reading progress works correctly (fresh load from persistence)
- Memory is properly managed (cache cleared when done)

## Additional Considerations

### Why This Bug Happens

The bug is triggered by SwiftUI's view update cycle:
1. User navigates (changes `currentPage` in ReaderViewModel)
2. Any `@Published` property in AppCoordinator changes (e.g., `isLoading`, `errorMessage`)
3. ContentView observes AppCoordinator and re-renders
4. ContentView calls `makeReaderViewModel()` again
5. New ReaderViewModel instance is created
6. `loadBook()` runs again, resetting to page 1

### Potential Triggers

Any of these AppCoordinator changes cause the bug:
- `isLoading` state changes
- `errorMessage` updates
- `userSettings` modifications
- `readingProgressList` updates

### Alternative Solutions Considered

1. **Make ContentView.body not depend on AppCoordinator state**
   - Not feasible - need to observe navigation state

2. **Use NavigationStack with .navigationDestination**
   - Would require iOS 16+ minimum
   - Major architecture change

3. **Store ReaderViewModel as @StateObject in App**
   - Violates separation of concerns
   - Difficult to manage lifecycle

The proposed caching solution is the most pragmatic fix that:
- Requires minimal code changes
- Preserves existing architecture
- Provides clear lifecycle management
- Solves the problem completely
