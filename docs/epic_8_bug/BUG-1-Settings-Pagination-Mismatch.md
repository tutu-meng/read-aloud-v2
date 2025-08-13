### Bug Prompt: Background Pagination vs Reader Display Settings Mismatch

- **Context**: The app performs background pagination via `BackgroundPaginationService` and renders content in `ReaderView` using `PageView`.
- **Question**: Which settings (font and paragraph spacing) are used for background pagination, and which settings are used for rendering in `ReaderView`? Are they identical so page boundaries match?

#### Current Code Paths
- **Background pagination uses**:
  - `BackgroundPaginationService.processBook(...)` builds a `PaginationService(textContent:userSettings:)` with `settings` loaded from persistence.
  - It then builds an attributed string via `PageView.createAttributedString(from:settings:)` using the same `UserSettings` and uses Core Text pagination through `PaginationService.calculatePageRange` with the attributed string to determine page breaks.
- **Reader display uses**:
  - `PageView.updateUIView` constructs an attributed string via `createAttributedString(from:settings:)` using `appCoordinator.userSettings` and assigns it to `UITextView`.

#### Risk
- If `UserSettings` consumed by background pagination differ from `appCoordinator.userSettings` at render time (e.g., due to a race or persistence drift), page content may not fit frames, causing truncated/overflowing text or misaligned page boundaries.

#### Root Cause (Updated)
- The saved/view size used by background pagination bounds is not the exact text drawable area.
- In `ReaderView`, we paginate/display inside a frame with subtractive chrome and text insets:
  - Container: `(width, height - 100)`
  - `PageView` applies `textContainerInset = (16, 16, 16, 16)`
  - Actual text drawable size = `(width - 32, height - 100 - 32)`
- Background currently uses the larger container, not the smaller drawable area, causing content overflow.

#### Acceptance Criteria
- Document explicitly which `UserSettings` fields affect layout for both paths: `fontName`, `fontSize`, `lineSpacing` (and any paragraph spacing multipliers derived from it).
- Confirm both background pagination and display use identical settings values and transformation rules (e.g., `paragraphStyle.lineSpacing = 4 * settings.lineSpacing`, `paragraphSpacing = 8 * settings.lineSpacing`).
- If not identical, propose unification.

#### Fix Plan
- Introduce `LayoutMetrics` with:
  - `chromeBottomHeight = 100`
  - `horizontalContentInset = 16`, `verticalContentInset = 16`
  - `computeTextDrawableSize(container: CGSize) -> CGSize` returning `(w - 2*16, h - 100 - 2*16)`.
- In `ReaderView`, compute `textSize = computeTextDrawableSize(geometry.size)` and pass to `viewModel.updateViewSize(textSize)`.
- `ReaderViewModel.updateViewSize` persists `textSize` via `PersistenceService.saveLastViewSize`.
- Background uses `PersistenceService.loadLastViewSize()` → identical bounds as display.
- Update `PaginationCache.cacheKey` to include a layout version suffix to invalidate old caches.

#### Verification (Add Tests)
- Unit: Given a container size, `computeTextDrawableSize` equals `(w - 32, h - 100 - 32)`.
- Persistence: After `updateViewSize(textSize)`, `loadLastViewSize()` returns the same `textSize`.
- Parity: Use `SettingsConsistencyTests` to assert first-page range equality using `bounds = textSize` for both background/display attributed strings.

#### What to Verify In Code
- Background service:
  - `BackgroundPaginationService.checkAndProcessNextBook()` loads settings via `PersistenceService.loadUserSettings()` and persists the cache key with that exact `settings`.
  - `calculateBatch(...)` calls `PageView.createAttributedString(from:settings:)` with the same `settings`.
- Reader display:
  - `PageView.updateUIView`: builds attributed string via `createAttributedString(from: appCoordinator.userSettings)`.

#### Request
- Confirm settings parity between background pagination and on-screen rendering, or file a fix to ensure both use the same `UserSettings` source and mapping.


