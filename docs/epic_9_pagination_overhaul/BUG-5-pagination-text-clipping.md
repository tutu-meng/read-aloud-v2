# BUG-5: Pagination Text Clipping

## Symptom

Pages sometimes show incomplete text — the last line(s) get clipped at the bottom. Observed between pages 34-35. The page content string IS correct (no gap in character indices), but the UITextView doesn't render all of it because `isScrollEnabled = false` clips overflow.

## Root Cause

Two different TextKit stacks calculate layout differently:

**Pagination** (`PaginationService.calculatePageRange`): standalone NSTextStorage/NSLayoutManager/NSTextContainer — calculates how many characters fit in bounds.

**Display** (`SinglePageViewController` in BookPagerView): UITextView with its own internal TextKit stack — renders the page content.

Even though the effective text area dimensions match mathematically `(370, 607)`, UITextView has subtle internal behaviors (content adjustments, baseline rounding, text container size clamping when `isScrollEnabled = false`) that can cause it to need slightly MORE vertical space than the bare TextKit stack predicted. Even 1px difference clips the last line.

## Plan

### Phase 1: Diagnostic test to measure the exact discrepancy

Create `PaginationLayoutParityTests.swift` that:
1. Paginates a CJK text sample using `PaginationService.calculatePageRange()`
2. For each page, creates a UITextView with identical settings as `SinglePageViewController`
3. Measures `usedRect` from UITextView's layoutManager
4. Asserts `usedRect.height <= available height` for every page
5. Logs exact pixel overflow per page

### Phase 2: Apply fix based on diagnostic findings

Most likely fix: apply a small height buffer (~2pt) in `PaginationService.calculatePageRange()` so pagination is slightly conservative — the last line always has room to render.

Files:
- `PaginationService.swift` line 250 — reduce effective height by buffer
- Bump cache version `pad16v2` → `pad16v3` to invalidate stale caches

### Phase 3: Verify fix

- New parity test passes (0 overflow pages)
- All 138 existing tests pass
- Visual check on simulator: pages 30-40, no clipped text
- Concatenation of all page contents still equals full book text
