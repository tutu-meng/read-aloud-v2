# PGN-OVERHAUL: Pagination System Improvement Plan

## Context

The current pagination system uses a **decoupled architecture** (PGN-9): `BackgroundPaginationService` paginates books in batches of 10 and saves to SQLite, while `ReaderViewModel` polls the cache every 2 seconds via Timer. Text layout is calculated via TextKit (NSLayoutManager) to match UITextView rendering. While the architecture is sound in principle, there are significant performance, correctness, and UX issues.

---

## Current Problems (by severity)

### HIGH

**P1: LayoutMetrics vertical inset mismatch (BUG)**
- `LayoutMetrics` subtracts 32px vertical insets (`2 * 16`) from height
- But `PageView.textContainerInset` was `(top: 0, left: 16, bottom: 0, right: 16)` -- vertical was 0
- Pagination calculated for 32px shorter height than UITextView actually rendered
- Result: ~1-2 wasted lines per page, ~100-200 extra unnecessary pages for a 4766-page book
- Files: `LayoutMetrics.swift`, `PageView.swift`

**P2: TabView + ForEach(0..<totalPages) creates thousands of views**
- For a 4766-page book, SwiftUI instantiates all views upfront
- When `totalPages` changes (every 2s during pagination), the entire ForEach rebuilds
- Causes UI stuttering and excessive memory usage
- File: `ReaderView.swift`

**P3: Only current page shows real content**
- `generatePageContent()` returns real text only for `viewModel.currentPage`
- All other pages show "Loading page X..." placeholder
- Causes visible content flash on every swipe
- File: `ReaderView.swift`

**P4: Double-polling architecture**
- BackgroundPaginationService polls every 5s for work
- ReaderViewModel polls SQLite every 2s for results
- Up to 7s latency before new pages appear; wastes CPU/battery
- Files: `BackgroundPaginationService.swift`, `ReaderViewModel.swift`

### MEDIUM

**P5: All page content loaded into memory at once**
- `bookPages: [String]` holds all pages (~7MB for large CJK books)
- SQLite `fetchCache()` loads all rows in a single query
- Files: `ReaderViewModel.swift`, `PaginationStore.swift`

**P6: Settings change triggers full re-pagination from page 1**
- User at page 2000 waits while pages 1-1999 are repaginated
- At 10 pages/batch with 0.1s delay, ~3 minutes to reach page 2000
- No priority pagination around current reading position
- File: `BackgroundPaginationService.swift`

**P7: No cancellation of stale pagination on settings change**
- Background service may still be paginating with OLD settings after a change
- Wastes CPU computing pages that will be immediately discarded
- File: `BackgroundPaginationService.swift`

**P8: PageView isScrollEnabled = true**
- Content can scroll within a page, contradicting the pagination model
- User might need to scroll within a page to see last few lines
- File: `PageView.swift`

### LOW

**P9: Character index calculation is placeholder (`page * 1000`)**
- Should use actual `startIndex` from `PageRange` for accurate position restoration
- File: `ReaderViewModel.swift`

**P10: Estimated totalPages wildly inaccurate for CJK/GBK files**
- Uses `fileSize / 2000` but GBK files have 2 bytes/char
- Can be 2-3x off for Chinese books
- File: `ReaderViewModel.swift`

**P11: `createAttributedString` lives in PageView (code smell)**
- Background services create a `PageView` instance just to call this method
- Should be a shared utility
- Files: `BackgroundPaginationService.swift`, `PaginationService.swift`

---

## Improvement Plan

### Phase 1: Fix Correctness Bugs ✅ COMPLETE

**1A. Fix LayoutMetrics/PageView mismatch (P1)** ✅
- Added vertical insets to `PageView`: `textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)`
- Bumped cache version: `"pad16v1"` -> `"pad16v2"` in `PaginationCache.cacheKey()` to invalidate old caches
- Files: `PageView.swift`, `PaginationCache.swift`

**1B. Fix character index placeholder (P9)** ✅
- Added `pageStartIndices: [Int]` array populated from `PageRange.startIndex` in ReaderViewModel
- `calculateCharacterIndex(for:)` now uses actual page boundaries instead of `page * 1000`
- File: `ReaderViewModel.swift`

**1C. Disable PageView scrolling (P8)** ✅
- Set `textView.isScrollEnabled = false` (pagination already calculates exact fit)
- File: `PageView.swift`

### Phase 2: Core Performance (the big wins)

**2A. Replace TabView with UIPageViewController wrapper (P2 + P3)**
- Create `BookPagerView` (`UIViewControllerRepresentable` wrapping `UIPageViewController`)
- Only 3 views exist at any time: current, previous, next
- Adjacent pages get real content from cache (no more "Loading..." flash)
- Files: New `Views/BookPagerView.swift`, modify `ReaderView.swift`, `ReaderViewModel.swift`

**2B. Replace polling with event-driven updates (P4)**
- `BackgroundPaginationService` posts `Notification` after each batch commit
- `ReaderViewModel` observes notification, calls `loadFromCache()` on receipt
- Remove 2-second Timer from ReaderViewModel
- Files: `BackgroundPaginationService.swift`, `ReaderViewModel.swift`

### Phase 3: Memory & Storage Optimization

**3A. Lazy page loading from SQLite (P5)**
- Add `fetchPage(bookHash:settingsKey:pageNumber:)` to `PaginationStore` (single-row query)
- Add `fetchPageCount()` and `fetchMeta()` methods
- Replace `bookPages: [String]` with LRU cache of ~20 pages
- Natural fit with Phase 2A (windowed pager only needs 3 pages at a time)
- Files: `PaginationStore.swift`, `ReaderViewModel.swift`, `PersistenceService.swift`

### Phase 4: UX Improvements

**4A. Priority pagination around current position (P6)**
- On settings change, pass current `characterIndex` as priority hint
- Background service paginates forward from that position first (~50 pages)
- Then fills in from page 1 sequentially
- Files: `BackgroundPaginationService.swift`, `ReaderViewModel.swift`

**4B. Add cancellation for stale pagination (P7)**
- Cancel in-progress pagination task when settings change
- Add per-book cancellation token checked in batch loop
- File: `BackgroundPaginationService.swift`

**4C. Better estimated totalPages (P10)**
- Factor in `book.textEncoding` (2 bytes/char for GBK)
- Refine estimate using actual average chars/page from first few paginated pages
- File: `ReaderViewModel.swift`

**4D. Extract `createAttributedString` to shared utility (P11)**
- Create `Utilities/TextStyling.swift` with static method
- Update `PageView`, `BackgroundPaginationService`, `PaginationService` to use it
- Files: New `Utilities/TextStyling.swift`, `PageView.swift`, `BackgroundPaginationService.swift`, `PaginationService.swift`

### Dependency Graph

```
Phase 1 (all parallel):          ✅ COMPLETE
  1A (LayoutMetrics) ──┐
  1B (Char index)   ───┤
  1C (Scroll disable) ─┘
           │
Phase 2 (parallel with each other):
  2A (UIPageViewController) ──┐
  2B (Event-driven updates) ──┤
           │                  │
Phase 3:   │                  │
  3A (Lazy loading) ──────────┘
           │
Phase 4 (all parallel):
  4A (Priority pagination)
  4B (Cancellation)
  4C (Better estimates)
  4D (Extract TextStyling)
```

## Verification

After each phase:
1. Run existing tests: `xcodebuild test -project ReadAloudApp/ReadAloudApp.xcodeproj -scheme ReadAloudApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
2. Build and run on simulator: open a large CJK book, verify:
   - Pages render without bottom gap (Phase 1)
   - No UI stuttering when scrolling through pages (Phase 2)
   - No "Loading page..." flash between pages (Phase 2)
   - Memory usage stays low for large books (Phase 3)
   - After settings change, pages near current position appear first (Phase 4)
