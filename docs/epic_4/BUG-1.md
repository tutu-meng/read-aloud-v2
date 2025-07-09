Ticket: BUG-1: Refactor paginateText to Use Core Text Layout
Type: Bug / Refactor
Assignee: Unassigned
Priority: Highest

Description:
There is a critical disconnect in the current PaginationService. The paginateText(content:settings:viewSize:) method, which provides the final [String] array of pages to the UI, is using an inaccurate, estimation-based calculatePagination function. This completely bypasses our precise Core Text layout calculations.

This task is to refactor the paginateText method to use the results from the accurate getOrCalculateFullLayout function. This will ensure that the text displayed to the user perfectly matches the pages calculated by Core Text.

Acceptance Criteria:

The legacy private method calculatePagination(content:settings:viewSize:) must be completely removed from the PaginationService.

The public method paginateText(content:settings:viewSize:) must be rewritten.

Inside the refactored paginateText, it must now perform the following steps:
a. Call the await getOrCalculateFullLayout(bounds: CGRect(origin: .zero, size: viewSize)) function to retrieve the accurate array of [NSRange] objects.
b. Create an empty [String] array to hold the page content.
c. Iterate through the returned [NSRange] array. For each range, extract the corresponding substring from the full content string.
d. Append each extracted substring to the [String] array.

The paginateText method must be marked as async since it will now depend on an asynchronous layout calculation.

After this change, the text content displayed on each page in the UI must exactly correspond to the layout calculated by the Core Text engine, reflecting the correct font size, view size, and other settings. The "500 character estimation" will no longer be used anywhere in the pagination process.