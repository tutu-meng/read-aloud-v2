Acceptance Criteria:

A private function, calculatePageRange(from:in:with:), is implemented within PaginationService, as seen in the provided code.

The function must accept three parameters:

An Int representing the startIndex of the text to measure from.

A CGRect representing the exact bounds of the view where the text will be rendered.

The full NSAttributedString of the book, containing all user-defined styles (font, size, line spacing).

Inside the function, a CTFramesetter must be created from the attributed string.

A CGPath must be created from the input CGRect to define the shape of the text container.

CTFramesetterCreateFrame must be called to generate a CTFrame. This performs the actual layout calculation.

The function must call CTFrameGetStringRange on the resulting CTFrame to get the visible character range.

The final result must be an exact NSRange (location and length) representing the characters that fit perfectly on the page. This NSRange is the sole return value of the function.

All Core Text calculations must be explicitly dispatched to a background thread (e.g., via DispatchQueue.global(qos: .userInitiated)) to prevent any blocking or stuttering of the main UI thread. An async wrapper for this function is the preferred implementation.