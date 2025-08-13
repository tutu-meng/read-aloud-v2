### Bug: Last line does not reach end-of-line; appears cut early

- Context: On CJK/GBK content pages, the final line on a page sometimes stops short of the right edge despite available space. Cached page text matches exactly, so loss is in rendering, not pagination/caching.

Symptoms
- Last 4–6 characters appear missing on screen, though `pageContent` equals cache JSON.
- Plenty of horizontal room remains in the line.

Confirmed
- Pagination uses CoreText with `.byCharWrapping` via paragraph style and correct UTF-16 ranges.
- UI uses `UITextView` with `.byCharWrapping`, `lineFragmentPadding=0`, and fixed insets.

Hypothesis
- TextKit layout variance for the last glyph cluster combined with font metrics and paragraph style may end line earlier (glyph bounding rect < container width).

Acceptance Criteria
- Last glyph on each page is laid out within container width (no premature wrap) and near the right edge for dense CJK.

Plan
1) Keep paragraphStyle.lineBreakMode = `.byCharWrapping` and ensure attributed range uses UTF-16 length.
2) Add verification test measuring the last glyph rect via `NSLayoutManager` against the same bounds used for pagination.
3) If needed, adjust `usesFontLeading`, kerning, or paragraph `tailIndent` to reconcile CoreText vs TextKit metrics.

Verification
- Automated unit test `testLastGlyphWithinContainerWidthForCJKSample` asserts the last glyph's `maxX` ≤ container width and reasonably near the right edge.

