# Bug: Page Navigation Causes Reload to Page 1

## Quick Summary
When users swipe to the next page while the book is still paginating, the app reloads and shows Page 1 again instead of Page 2.

## Steps to Reproduce
1. Open any book for the first time
2. Immediately swipe right to go to page 2 (before pagination completes)
3. Watch what happens

## What Actually Happens
- The reader view reloads/refreshes
- Page 1 content is shown again
- User is back at the beginning of the book
- Page indicator might briefly show "2" then revert to "1"

## What Should Happen
- Page 2 content should display immediately
- No reloading or view refresh
- Navigation should work normally

## Impact
- Users cannot read past page 1 until pagination finishes
- Makes the app appear broken or frozen
- Very poor user experience for the primary use case

## Visual Behavior
```
User opens book → [Page 1 shown] → User swipes right → [Brief loading] → [Page 1 shown again] ❌

Should be:
User opens book → [Page 1 shown] → User swipes right → [Page 2 shown] ✅
```

## Severity
**CRITICAL** - Core functionality is broken. Users cannot read books normally.
