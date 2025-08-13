### Verification: Background Pagination and Reader Display Use Identical Settings

- **Goal**: Ensure the settings used to compute page boundaries in the background are identical to the ones used for on-screen rendering, so all content fits correctly within the frame without truncation or overflow.

#### Checklist
- **Same settings source**
  - Background: `PersistenceService.loadUserSettings()` in `BackgroundPaginationService`.
  - Reader: `appCoordinator.userSettings` in `PageView.updateUIView`.
- **Same mapping rules**
  - `fontName` and `fontSize` → UIFont in `PageView.getFont(name:size:)`.
  - `lineSpacing` → `paragraphStyle.lineSpacing = 4 * settings.lineSpacing` and `paragraphStyle.paragraphSpacing = 8 * settings.lineSpacing` in `PageView.createAttributedString`.
- **Same attributed string function**
  - Both paths call `PageView.createAttributedString(from:settings:)`.
- **Same bounds (critical)**
  - Drawable size used by both: `(width - 32, height - 100 - 32)` (16pt inset each side, 100pt chrome at bottom).
  - Persist this exact size via `PersistenceService.saveLastViewSize`; background uses `loadLastViewSize` for pagination bounds.

#### Manual Steps
1. Set custom settings in the app (e.g., font = Georgia, size = 22, lineSpacing = 1.6).
2. Restart app; confirm settings persist (library/settings UI reflects custom values).
3. Open a book; verify pages render without clipping or overflow.
4. Inspect pagination cache key incorporates the same settings and view size.

#### Automated Tests
- Layout metrics test: Verify `computeTextDrawableSize(container:)` returns `(w - 32, h - 100 - 32)`.
- Persistence test: After calling `updateViewSize(drawableSize)`, `loadLastViewSize()` equals `drawableSize`.
- Parity test: Using `drawableSize` as bounds, assert first-page range equality between attributed strings built for background and display.

#### Acceptance Criteria
- Background pagination and reader display use the same `UserSettings` values and mapping rules.
- Drawable bounds are identical; page content displays fully in `ReaderView` without layout mismatch.


