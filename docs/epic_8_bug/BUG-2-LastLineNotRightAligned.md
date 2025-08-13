### Bug-2: Last line does not reach end-of-line; appears cut early

- Context: On CJK/GBK content pages, the final line on a page sometimes stops short of the right edge despite available space. Cached page text matches exactly. Root cause likely lies in pagination using a different effective width than UI rendering.

Symptoms
- Last 4–6 characters appear missing on screen, though `pageContent` equals cache JSON.
- Plenty of horizontal room remains in the line.

Confirmed
- UI and cache text match byte-for-byte for each page.
- Insets in UI are set (horizontal 16, padding 0), and attributed range uses UTF-16 length.

To Verify (Width Parity)
- Ensure pagination and UI rendering use the exact same drawable width:
  - Drawable width formula: `container.width - 2 * 16` (16pt left/right) and height adjusted by chrome.
  - Pagination bounds width must equal UI `NSTextContainer.size.width` used by `UITextView`.

Hypothesis
- Pagination is using a slightly wider width than UI container (e.g., missing 16pt insets or safe-area adjustment), causing CoreText to break later than TextKit and making the last few glyphs not fit when rendered.

Acceptance Criteria
- Pagination bounds width equals UI text container width (in points) for the same `UserSettings` and `LayoutMetrics`.
- Last glyph on each page is laid out within container width (no premature wrap) and near the right edge for dense CJK.

Plan
1) Verify width parity programmatically: compute `LayoutMetrics.computeTextDrawableSize(container:)` and assert paginator’s width equals UI text container width.
2) Keep paragraphStyle.lineBreakMode = `.byCharWrapping` and ensure attributed range uses UTF-16 length (already fixed).
3) Add test to measure last glyph rect via `NSLayoutManager` using the same bounds used by pagination.
4) If mismatch detected, adjust background pagination to use the same drawable size the UI persists and uses, and ensure no additional safe-area or scroll insets affect UI width.

Verification
- Automated unit tests:
  - `testPaginationAndUITextContainerUseSameWidth`: asserts paginator bounds width equals `NSTextContainer.size.width`.
  - `testLastGlyphWithinContainerWidthForCJKSample`: asserts the last glyph's `maxX` ≤ container width and near the right edge.

