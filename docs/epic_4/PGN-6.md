# PGN-6: Fix Page Navigation Reload Bug

## Bug Description

When a user opens a book for the first time and attempts to navigate to the next page before the initial pagination completes, the app reloads and displays Page 1 again instead of advancing to Page 2.

1. **Current Behavior:**
   - User opens a book → Page 1 displays correctly and pagination starts in background
   - User swipes to next page before pagination completes
   - App reloads/refreshes and shows Page 1 content again (not Page 2)
   - Navigation essentially resets to the beginning
   - A second pagination process may start
   - User is stuck on Page 1 until pagination completes

2. **Expected Behavior:**
   - User opens a book → Page 1 displays and pagination starts
   - User swipes to next page before pagination completes
   - Reader should immediately show Page 2 content
   - Navigation should work normally regardless of pagination state
   - No reloading or resetting should occur

## Root Cause Analysis

The issue likely stems from:
1. Navigation triggering a reload/refresh of the entire reader view
2. State being reset when `currentPage` changes during initial pagination
3. `loadBook()` being called again when it shouldn't be
4. Missing proper state preservation during navigation
5. Possible re-initialization of ReaderViewModel or view recreation

## Acceptance Criteria

1. **Immediate Page Navigation**
   - When user swipes to any page, content must update immediately
   - Use estimated pagination if accurate pagination isn't complete
   - No loading delay or blank pages during navigation

2. **Single Pagination Process**
   - Only one pagination process should run per book load
   - Navigation should not trigger additional pagination
   - Existing pagination should continue uninterrupted

3. **Correct Page Display**
   - Current page content must always match `currentPage` value
   - Page indicator must show correct page number
   - Content transitions must be smooth

4. **State Management**
   - Track if pagination is in progress to prevent duplicates
   - Preserve navigation state during pagination
   - Handle rapid page changes gracefully

## Technical Requirements

1. **Add Pagination State Tracking**
   ```swift
   @Published var isPaginating = false
   private var paginationTask: Task<Void, Never>?
   ```

2. **Guard Against Duplicate Pagination**
   - Check `isPaginating` before starting new pagination
   - Cancel previous task if re-pagination is needed
   - Set flag when pagination starts/completes

3. **Fix Page Content Updates**
   - Ensure `updatePageContent()` works during initial load
   - Show estimated content immediately on navigation
   - Don't wait for pagination to complete

4. **Improve Navigation Handling**
   - Decouple navigation from pagination
   - Allow navigation during all app states
   - Preserve user's navigation intent

## Test Scenarios

1. **Basic Navigation During Load**
   - Open large book (>1MB)
   - Immediately swipe to page 2
   - Verify page 2 content shows (not page 1 again)
   - Verify no reload/refresh occurs
   - Verify only one pagination process

2. **Rapid Navigation**
   - Open book
   - Quickly swipe through pages 1→2→3→4
   - Verify each page shows different content
   - Verify smooth transitions

3. **Navigation After Pagination**
   - Open book and wait for pagination
   - Navigate normally
   - Verify accurate page content

4. **Edge Cases**
   - Navigate to last page during pagination
   - Navigate backwards during pagination
   - Close and reopen book during pagination

## Implementation Notes

Focus areas:
1. **ReaderViewModel**:
   - `loadBook()` - Should only be called once on init, not on navigation
   - `currentPage` didSet - Should not trigger reload or re-initialization
   - `updatePageContent()` - Must work during initial pagination
   - `performBackgroundPagination()` - Track state properly

2. **ReaderView**:
   - Check if view is being recreated on navigation
   - Ensure TabView doesn't trigger view reload
   - Verify `@StateObject` vs `@ObservedObject` usage

3. **ContentView**:
   - Ensure ReaderViewModel isn't recreated on state changes
   - Check if navigation causes view hierarchy changes

## Success Metrics

- Zero duplicate pagination processes
- Immediate page content on navigation
- No page reloads or resets during navigation
- Correct page content displayed (Page 2 when navigating to Page 2)
- Smooth user experience throughout

## Priority

**HIGH** - This is a critical UX issue that makes the app feel broken during the most common user action (reading and navigating pages).
