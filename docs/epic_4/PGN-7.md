# PGN-7: Placeholder Content Shown Instead of Actual Book Content

## Bug Description

After fixing the page reload bug (PGN-6), a new issue has been discovered: when users navigate to page 2 (or any page) during initial pagination, they see placeholder content instead of the actual book content.

1. **Current Behavior:**
   - User opens a book → Page 1 displays with actual content
   - User swipes to page 2 before pagination completes
   - Page 2 displays but shows placeholder text: "This is placeholder content for page 2..."
   - The navigation works (no reload), but the content is wrong
   - User sees generic placeholder instead of actual book text

2. **Expected Behavior:**
   - User opens a book → Page 1 displays with actual content
   - User swipes to page 2 before pagination completes
   - Page 2 should show actual book content (even if using estimated pagination)
   - Content should be from the actual book file, not placeholder text

## Root Cause Analysis

The issue stems from the `updatePageContent()` method in ReaderViewModel:

```swift
private func updatePageContent() {
    if !bookPages.isEmpty && currentPage < bookPages.count {
        pageContent = bookPages[currentPage]
    } else {
        // Fallback to placeholder content
        pageContent = """
        Page \(currentPage + 1) of \(book.title)
        
        This is placeholder content for page \(currentPage + 1).
        ...
        """
    }
}
```

When pagination hasn't completed:
1. `bookPages` array is empty
2. The method falls back to placeholder content
3. `fullBookContent` is available but not being used
4. `showEstimatedPageContent()` exists but isn't called from `updatePageContent()`

## Impact

- Users see meaningless placeholder text instead of actual book content
- Makes the app appear broken or incomplete
- Degrades the reading experience significantly
- The two-phase loading strategy (immediate + background) isn't working as designed

## Acceptance Criteria

1. **Immediate Content Display**
   - When navigating to any page, show actual book content immediately
   - Use estimated pagination if accurate pagination isn't ready
   - Never show placeholder text when real content is available

2. **Content Quality**
   - Estimated content should be reasonable approximation
   - Page boundaries might not be perfect but content must be real
   - Smooth transition when accurate pagination completes

3. **Consistent Behavior**
   - All pages should show real content
   - Works during initial load and navigation
   - No regression of the PGN-6 fix (no reloads)

## Technical Requirements

1. **Fix updatePageContent() Logic**
   ```swift
   private func updatePageContent() {
       if !bookPages.isEmpty && currentPage < bookPages.count {
           // Use accurate pagination if available
           pageContent = bookPages[currentPage]
       } else if !fullBookContent.isEmpty {
           // Use estimated content if book is loaded
           showEstimatedPageContent(for: currentPage)
       } else {
           // Only show placeholder if no content at all
           pageContent = "Loading..."
       }
   }
   ```

   **Current Issue**: The method jumps straight from checking `bookPages` to showing placeholder, completely skipping the check for `fullBookContent` that exists in `goToPage()`.

2. **Ensure fullBookContent Persists**
   - Verify `fullBookContent` is populated after loading
   - Don't clear it after pagination completes
   - Make it available for estimated pagination

3. **Improve showEstimatedPageContent**
   - Make it synchronous or handle async properly
   - Ensure it updates `pageContent` correctly
   - Handle edge cases (last page, etc.)

## Test Scenarios

1. **Basic Navigation Test**
   - Open a book
   - Immediately swipe to page 2
   - Verify: Real book content shows (not placeholder)
   - Continue swiping through pages
   - Verify: All pages show actual content

2. **Content Verification**
   - Open a known book (e.g., Alice in Wonderland)
   - Navigate to page 2 before pagination completes
   - Verify: Content is from the actual book
   - Check that text is continuous (not repeated)

3. **Pagination Transition**
   - Navigate using estimated content
   - Wait for pagination to complete
   - Verify: Content updates smoothly
   - Page boundaries adjust to accurate positions

4. **Edge Cases**
   - Navigate to last page during pagination
   - Navigate backward during pagination
   - Rapidly change pages

## Implementation Notes

### ReaderViewModel Changes Needed

1. **updatePageContent()**
   - Check `fullBookContent` before showing placeholder
   - Call `showEstimatedPageContent()` when needed
   - Only show minimal loading text if truly no content

2. **showEstimatedPageContent()**
   - Ensure it's called correctly
   - Make it update `pageContent` reliably
   - Handle the async nature properly

3. **loadBook() Flow**
   - Verify `fullBookContent` is set correctly
   - Ensure it's retained during pagination
   - Check `showInitialContent()` logic

### State Management

- `fullBookContent`: Should contain entire book text
- `bookPages`: Array of paginated content (empty until pagination done)
- `pageContent`: Currently displayed page content
- Need to ensure proper fallback chain

## Priority

**HIGH** - This directly impacts the primary user experience. Users cannot read books properly if they see placeholder text instead of actual content.

## Related Issues

- **PGN-6**: Page reload bug (fixed) - The navigation now works but exposed this content issue
- **Original Design**: Two-phase loading should show estimated content immediately

## Implementation Plan

### Quick Fix (Recommended)
Copy the logic from `goToPage()` into `updatePageContent()`:

```swift
private func updatePageContent() {
    // Use actual book content if available
    if !bookPages.isEmpty && currentPage < bookPages.count {
        pageContent = bookPages[currentPage]
    } else if !fullBookContent.isEmpty {
        // Show estimated content immediately
        Task { @MainActor in
            showEstimatedPageContent(for: currentPage)
        }
    } else {
        // Only show loading if truly no content
        pageContent = "Loading..."
    }
}
```

### Why This Works
- `goToPage()` already has the correct logic but it's not used by `currentPage` didSet
- The TabView binding changes `currentPage` which triggers `updatePageContent()`
- By adding the `fullBookContent` check, we ensure real content is always shown

## Success Metrics

- Zero placeholder content shown when book is loaded
- Actual book text visible on all pages during navigation
- Smooth reading experience regardless of pagination state
- User can read the book immediately after opening
