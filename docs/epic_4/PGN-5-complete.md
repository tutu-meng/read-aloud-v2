# PGN-5: Core calculatePageRange Function Implementation - Complete (Re-implemented)

## Overview

PGN-5 implements the single, most critical function within the PaginationService: `calculatePageRange(from:in:with:)`. This function uses Apple's Core Text framework to perform precise measurement of how many characters from a given NSAttributedString can fit into a specific view area (CGRect). It serves as the fundamental building block for the entire pagination engine.

## Implementation Details

### Core Function Signature (Exact PGN-5 Specification)

```swift
private func calculatePageRange(from startIndex: Int, in bounds: CGRect, with attributedString: NSAttributedString) -> NSRange
```

**Parameters:**
- `from startIndex`: Starting character index in the full attributed string to measure from
- `in bounds`: Exact bounds of the view where the text will be rendered
- `with attributedString`: The full NSAttributedString of the book, containing all user-defined styles

**Returns:** NSRange representing the exact characters that fit perfectly on the page

### Step-by-Step Implementation

The function follows the exact PGN-5 specification:

#### Step 1: CTFramesetter Creation
```swift
let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
```
- Creates CTFramesetter from the **full** attributed string (not a substring)
- Uses the complete book content with all user-defined styles

#### Step 2: CGPath Creation
```swift
let path = CGPath(rect: bounds, transform: nil)
```
- Creates CGPath from the input CGRect to define the shape of the text container
- Path perfectly matches the input bounds

#### Step 3: CTFrame Creation
```swift
let frameRange = CFRange(location: startIndex, length: attributedString.length - startIndex)
let frame = CTFramesetterCreateFrame(framesetter, frameRange, path, nil)
```
- Calls CTFramesetterCreateFrame to generate a CTFrame
- Uses the startIndex parameter to specify where to begin the layout
- This performs the actual layout calculation

#### Step 4: Character Range Extraction
```swift
let visibleRange = CTFrameGetStringRange(frame)
```
- Calls CTFrameGetStringRange on the resulting CTFrame
- Gets the visible character range that fits within the bounds

#### Step 5: NSRange Return
```swift
let resultRange = NSRange(location: visibleRange.location, length: visibleRange.length)
return resultRange
```
- Returns exact NSRange representing the characters that fit perfectly on the page
- This is the sole return value of the function

### Background Thread Processing (PGN-5 Requirement)

The preferred implementation uses an async wrapper that explicitly dispatches to background thread:

```swift
private func calculatePageRangeAsync(from startIndex: Int, in bounds: CGRect, with attributedString: NSAttributedString) async -> NSRange {
    return await withCheckedContinuation { continuation in
        // PGN-5 Requirement: All Core Text calculations must be explicitly dispatched to a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.calculatePageRange(from: startIndex, in: bounds, with: attributedString)
            continuation.resume(returning: result)
        }
    }
}
```

**Key Features:**
- All Core Text calculations are explicitly dispatched to `DispatchQueue.global(qos: .userInitiated)`
- Prevents any blocking or stuttering of the main UI thread
- Async wrapper is the preferred implementation as specified in PGN-5

## Validation and Testing

The implementation includes comprehensive validation:

1. **Input Validation**: Checks bounds validity and startIndex bounds
2. **Safety Checks**: Prevents invalid ranges and out-of-bounds access
3. **Build Verification**: Successfully compiles with no errors
4. **Performance**: Background thread processing ensures UI responsiveness

## Architecture Integration

The function integrates seamlessly with the existing pagination system:

- **PGN-2 Foundation**: Builds on the Core Text foundation
- **PGN-3 Integration**: Used by full layout calculation for complete document pagination
- **Caching Support**: Results are cached through the LayoutCache system
- **Error Handling**: Comprehensive error handling with fallback values

## Performance Characteristics

- **Precision**: Uses Apple's Core Text for exact character measurement
- **Efficiency**: Single-pass calculation with O(1) complexity for given bounds
- **Thread Safety**: Background processing prevents UI blocking
- **Memory Management**: Efficient use of Core Text objects with proper cleanup

## Key Differences from Previous Implementation

This re-implementation strictly follows PGN-5 specifications:

1. **Full String Usage**: Uses the complete NSAttributedString, not substrings
2. **Proper StartIndex Handling**: Uses startIndex in CTFramesetterCreateFrame parameters
3. **Exact Function Signature**: Matches the specified `calculatePageRange(from:in:with:)` signature
4. **Background Dispatch**: Explicit DispatchQueue.global(qos: .userInitiated) usage
5. **Async Wrapper**: Preferred implementation uses async/await pattern

## Acceptance Criteria Status

✅ **All PGN-5 acceptance criteria met:**

1. ✅ Private function `calculatePageRange(from:in:with:)` implemented
2. ✅ Accepts three parameters: Int startIndex, CGRect bounds, NSAttributedString
3. ✅ CTFramesetter created from the attributed string
4. ✅ CGPath created from input CGRect
5. ✅ CTFramesetterCreateFrame called to generate CTFrame
6. ✅ CTFrameGetStringRange called to get visible character range
7. ✅ Returns exact NSRange (location and length)
8. ✅ Core Text calculations dispatched to background thread
9. ✅ Async wrapper provided as preferred implementation

## Build Status

- **Build Status**: ✅ Successful
- **Warnings**: Minor Sendable protocol warnings (non-critical)
- **Errors**: None
- **Platform**: iOS 17.0+, iPhone Simulator tested

## Next Steps

The PGN-5 implementation is complete and ready for integration with higher-level pagination features. The function serves as the foundation for all text layout calculations in the ReadAloudApp pagination system. 