### UI-5: Replace reader dots with percentage indicator (lower-right)

#### Summary
Refactor the current "dots" progress indicator at the lower-right of `ReaderView` to display a percentage of book completion instead. The percentage should be derived from the current page index and total page count when available. During ongoing pagination, display an approximate percentage using processed pages.

#### Motivation
- Dots convey limited information for long books and are visually ambiguous.
- A percentage provides clearer progress feedback and takes minimal space.

#### Requirements
- Replace dots with a percentage label (e.g., "42%") at lower-right, consistent with current insets.
- Use page-number based percentage when `isPaginationComplete == true`.
- When pagination is incomplete:
  - Prefer page-based percentage using `processedPages/estimatedTotalPages` if `totalPages` unknown.
  - Avoid regressions in performance and reflows.
- Respect theme (light/dark), readability, and accessibility (Dynamic Type/VoiceOver label).

#### Plan
1) ViewModel
   - Add a computed `progressPercent`:
     - If `isPaginationComplete`: `Double(currentPage + 1) / Double(totalPages)`.
     - Else: `Double(min(currentPage + 1, processedPages)) / Double(max(estimatedTotalPages(), 1))`.
     - Expose as integer 0–100 with rounding.
   - Keep existing publishers; do not change public navigation APIs.

2) View
   - Replace the dots view in `ReaderView` overlay with a small `Text("\(progressPercent)%")` styled label.
   - Create a tiny `ProgressBadgeView(percent:Int)` for styling reuse; pinned to bottom-trailing with safe-area insets.
   - Apply appropriate padding, background blur (or subtle capsule), and foregroundColor aligned to theme.

3) Accessibility
   - Add accessibilityLabel: "Reading progress, \(percent) percent".
   - Support Dynamic Type scaling; ensure truncation never hides the number.

4) Performance
   - Avoid recomputation loops; compute percent from existing `@Published` state.
   - No additional timers or heavy observers.

5) Edge cases
   - totalPages == 0 → show 0%.
   - currentPage beyond processed pages (rare) → clamp to processedPages during incomplete state.

#### Diagram
```mermaid
flowchart LR
  A[ReaderViewModel state
  - currentPage
  - totalPages
  - isPaginationComplete
  - processedPages
  - estimatedTotalPages] --> B{Compute percent}
  B -->|complete| C[percent = (currentPage+1)/totalPages]
  B -->|incomplete| D[percent = min(currentPage+1, processedPages)/estimatedTotalPages]
  C --> E[ReaderView ProgressBadgeView]
  D --> E[ReaderView ProgressBadgeView]
```

#### Validation
- Manual
  - Load a fully paginated small sample → indicator shows 100% on last page, ~50% mid-book.
  - During pagination: open large book, navigate early → percent increases as pages are processed.
  - Theme check: dark/light; ensure contrast ≥ WCAG AA.
  - Rotation/resizing: percent stays anchored, no overlap with other chrome.
  - Accessibility: VoiceOver reads correct label; Dynamic Type enlarges text without clipping.

- Automated tests (to add)
  - Unit: Given `(currentPage,totalPages)` pairs, computed percent matches expected rounding.
  - Incomplete pagination: `processedPages` and `estimatedTotalPages` produce monotonic, clamped percent.
  - UI snapshot: `ProgressBadgeView` renders text and adapts to theme.
  - Integration: When `currentPage` updates, percent publisher updates once with correct value.

#### Acceptance Criteria
- The dots indicator is removed and replaced with a percentage label at the same location.
- For complete pagination, percent equals `(currentPage+1)/totalPages` rounded to nearest integer [0,100].
- For incomplete pagination, percent uses processed/estimated and never decreases as more pages are processed.
- Indicator respects themes and accessibility guidelines.
- Tests covering percent computation and basic rendering pass.

#### Out of scope
- Changing other chrome layout or adding progress bar.
- Character-based percentage; we standardize on page-based.

---

#### Update (2025-08-13)
- Decision: Remove the percentage indicator altogether for now.
- Rationale: The percent did not reliably update on page change using only existing view state without adding new observers/computed state in `ReaderViewModel`. To avoid partial/incorrect UX, we reverted to showing only the left-side text ("Page X of Y").
- Status: Implemented. Bottom bar now displays only "Page X of Y"; no dots, no percent.
- Next step (optional, future): Reintroduce a stable percent by computing a `progressPercent` in `ReaderViewModel` that updates on `currentPage`, `totalPages`, and `paginationProgress` changes, then bind the view to that single source of truth.


