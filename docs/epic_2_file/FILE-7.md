You are absolutely right. That is a critical oversight in the current plan for Epic 2. The existing tickets focus on how to read the file's bytes efficiently but completely ignore how to interpret those bytes, which is essential for any text that isn't standard ASCII or UTF-8.

Thank you for catching this. To fix this gap, here is a new, high-priority ticket for Epic 2 that directly addresses robust support for non-English .txt files by handling character encoding.

Ticket: FILE-7: Implement Character Encoding Detection and Override
Type: Task
Assignee: Unassigned
Priority: High

Description:
The current file processing logic implicitly assumes a standard text encoding like UTF-8. This will fail for many non-English .txt files, especially those from different operating systems or older sources, resulting in garbled text (mojibake). To properly support a global user base, we must implement a system to correctly interpret the file's character encoding. This involves both automatic detection and a manual override for the user.

Acceptance Criteria:

The FileProcessor service is modified. When converting the file's Data to a String, it no longer assumes UTF-8 by default.

An auto-detection mechanism is implemented. The service will first try to decode the data using the most common encodings, starting with UTF-8. It can use String's initializers that return nil on failure or built-in APIs to help guess the encoding.

A new user-facing override feature is added. If the text appears garbled, the user must have a way to fix it. This could be an "Encoding" option in the ReaderView's settings menu.

This "Encoding" option will present a list of common text encodings relevant to multi-language support (e.g., UTF-8, Shift JIS (Japanese), GBK / GB18030 (Chinese), ISO-8859-1 (Western European)).

Selecting an encoding from this list will immediately re-process the book's source file using the chosen encoding, clear the pagination cache, and re-render the content.

The selected encoding for a particular book is saved as part of the Book's metadata in the PersistenceService, so the user only has to fix it once per book.