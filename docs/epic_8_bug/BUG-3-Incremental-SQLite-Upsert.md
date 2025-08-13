## BUG-3: Replace JSON pagination cache with SQLite incremental upserts (via DatabaseService layer)

### Summary
Pagination currently rewrites an ever-growing JSON file every N pages, causing write amplification, potential UI stutter, and fragility on interruption. Move to SQLite with UPSERT to write pages incrementally and atomically, while keeping the UI read path simple and fast.

### Status
- Proposed

### Motivation / Problem Statement
- JSON cache is fully rewritten periodically (e.g., every 10 pages). As the book grows, writes become heavier and slower.
- Power and performance costs increase (large sequential writes, unnecessary JSON serialization/deserialization).
- Crash/kill during write can corrupt or lose progress.
- Cleanup of non-current settings caches is more complex.

### Goals
- Incremental, idempotent page writes using UPSERT.
- Atomic batch commits with minimal I/O.
- Easy lookup by `(book_hash, settings_key, page_number)`.
- Efficient cleanup of stale caches when settings or view size change.
- Optional: store only ranges (UTF-16 indices), not duplicated page content.

### Non-Goals
- Change UI flow: Reader continues reading from the cache transparently.
- Change pagination algorithm (already aligned to TextKit).

### Architecture update
- Introduce a dedicated `DatabaseService` (SQLite wrapper) that owns the DB file, connection, pragmas, migrations, and exposes DAO-style stores.
- `PersistenceService` becomes an orchestrator that delegates page-cache calls to `PaginationStore` and can later delegate book-library, progress, etc., to other stores.
- Initial stores:
  - `PaginationStore` (this ticket)
  - Future: `LibraryStore`, `ReadingProgressStore` (optional migration from JSON later)

```mermaid
flowchart LR
  UI[ReaderViewModel / BackgroundPaginationService] -->|domain APIs| PS[PersistenceService]
  PS -->|delegates| DB[DatabaseService]
  DB -->|DAO| PAG[PaginationStore]
  DB -->|DAO (future)| LIB[LibraryStore]
  DB -->|DAO (future)| PROG[ReadingProgressStore]
```

### Schema (single DB, shared for future data)
```sql
-- DB: Application Support/ReadAloudApp/pagination.sqlite

PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;

CREATE TABLE IF NOT EXISTS page_cache (
  book_hash     TEXT NOT NULL,
  settings_key  TEXT NOT NULL,
  page_number   INTEGER NOT NULL,
  start_index   INTEGER NOT NULL,
  end_index     INTEGER NOT NULL,
  content       TEXT NULL,
  last_updated  REAL NOT NULL DEFAULT (strftime('%s','now')),
  PRIMARY KEY (book_hash, settings_key, page_number)
);

CREATE TABLE IF NOT EXISTS page_meta (
  book_hash             TEXT NOT NULL,
  settings_key          TEXT NOT NULL,
  last_processed_index  INTEGER NOT NULL,
  is_complete           INTEGER NOT NULL DEFAULT 0, -- 0/1
  total_pages           INTEGER NULL,
  last_updated          REAL NOT NULL DEFAULT (strftime('%s','now')),
  PRIMARY KEY (book_hash, settings_key)
);

CREATE INDEX IF NOT EXISTS idx_cache_lookup
  ON page_cache(book_hash, settings_key, page_number);

-- Optional for range-based queries
CREATE INDEX IF NOT EXISTS idx_cache_ranges
  ON page_cache(book_hash, settings_key, start_index);
```

### Write Path (BackgroundPaginationService)
- Open DB once per process; keep a small wrapper around `libsqlite3`.
- For each batch of pages computed:
  - BEGIN IMMEDIATE
  - For each page:
    ```sql
    INSERT INTO page_cache (
      book_hash, settings_key, page_number,
      start_index, end_index, content, last_updated
    ) VALUES (?, ?, ?, ?, ?, ?, unixepoch())
    ON CONFLICT(book_hash, settings_key, page_number)
    DO UPDATE SET
      start_index=excluded.start_index,
      end_index=excluded.end_index,
      content=excluded.content,
      last_updated=unixepoch();
    ```
  - Upsert meta:
    ```sql
    INSERT INTO page_meta (
      book_hash, settings_key, last_processed_index,
      is_complete, total_pages, last_updated
    ) VALUES (?, ?, ?, ?, ?, unixepoch())
    ON CONFLICT(book_hash, settings_key)
    DO UPDATE SET
      last_processed_index=excluded.last_processed_index,
      is_complete=excluded.is_complete,
      total_pages=COALESCE(excluded.total_pages, page_meta.total_pages),
      last_updated=unixepoch();
    ```
  - COMMIT

Notes:
- Use WAL + synchronous=NORMAL for fast, durable writes.
- If storing ranges-only, set `content=NULL` and derive text on read via memory-mapped file using UTF-16 indices.

### Read Path (Reader)
- Determine `settings_key` using the existing cacheKey logic aligned with `LayoutMetrics`.
- Page count/progress:
  - `SELECT COUNT(*) FROM page_cache WHERE book_hash=? AND settings_key=?;`
  - `SELECT is_complete, total_pages FROM page_meta WHERE book_hash=? AND settings_key=?;`
- Page fetch:
  - `SELECT content, start_index, end_index FROM page_cache WHERE book_hash=? AND settings_key=? AND page_number=?;`
  - If `content IS NULL`, slice from the book’s memory-mapped `NSString` with UTF-16 indices to build the attributed string.

### Cleanup & Invalidation
- On app start or settings/view-size change:
  - Delete stale data:
    ```sql
    DELETE FROM page_cache WHERE book_hash=? AND settings_key<>?;
    DELETE FROM page_meta  WHERE book_hash=? AND settings_key<>?;
    ```
- When starting a new pagination pass for a new `settings_key`, leave prior keys in place until confirmed switch, then cleanup.

### Migration (from JSON)
- If JSON cache exists for `(book_hash, settings_key)` and DB is empty for that pair:
  - Import pages within a single transaction using the UPSERT statements above.
  - Populate `page_meta` accordingly.
  - Remove the JSON file after successful commit.

### Test Plan
- DB bootstrap:
  - Creates schema on first open; WAL mode active.
- UPSERT idempotence:
  - Writing the same `page_number` updates without duplicating rows.
- Atomic batch:
  - Simulate failure mid-batch; verify no partial pages visible post-rollback.
- Read parity:
  - Reader loads page N; `content` equals the previously written content (or equals slice for ranges-only) and matches UI render.
- Cleanup correctness:
  - Stale `(book_hash, other_settings_key)` rows removed; current key preserved.
- Migration:
  - Import from existing JSON; page count and meta match; JSON removed.
- Performance:
  - Long book pagination runs with bounded write time per batch (no large JSON rewrites).

Additional layering tests:
- `DatabaseService` opens once, sets WAL/synchronous pragmas; schema present.
- `PaginationStore.upsertBatch` writes pages and meta in a transaction; idempotent.
- `PersistenceService` only delegates, has no direct SQLite calls.

### Acceptance Criteria
- Background pagination persists pages incrementally; no large JSON writes.
- Reader can navigate content using the DB-backed cache with the same UX as before.
- Settings/view-size changes remove stale pages and restart cleanly.
- Data remains consistent across app restarts and interruptions.

### Implementation Steps
1) Create `Sources/ReadAloudApp/Services/Database/DatabaseService.swift`
   - Manages SQLite connection (libsqlite3), WAL/synchronous pragmas.
   - Runs schema migrations (create `page_cache`, `page_meta`).
   - Provides low-level helpers: prepare/bind/step, runInTransaction.
2) Create `Sources/ReadAloudApp/Services/Database/PaginationStore.swift`
   - Public APIs:
     - `upsertBatch(bookHash:settingsKey:viewSize:pages:lastProcessedIndex:isComplete:totalPages:)`
     - `fetchCache(bookHash:settingsKey:) -> PaginationCache?`
     - `deleteAllForBook(_:)`, `deleteAllExcept(bookHash:keepSettingsKey:)`
3) Refactor `PersistenceService`
   - Replace inline SQLite usage with calls to `PaginationStore`.
   - Keep JSON compatibility shims out; only DB path used after migration.
4) Wire callers
   - `BackgroundPaginationService` uses `PersistenceService.savePaginationCache` (delegates to `PaginationStore.upsertBatch`).
   - `ReaderViewModel` uses `PersistenceService.loadPaginationCache` (delegates to `PaginationStore.fetchCache`).
5) Project updates
   - Link `libsqlite3`.
   - Ensure new source paths included in build.
6) Tests
   - Unit tests for `PaginationStore`, integration tests for UI parity unchanged.

### Notes for future expansion
- Add `LibraryStore` and `ReadingProgressStore` to the same DB, with migrations guarded by a `schema_version` table.
- Keep DAOs small and focused; transactions at store-layer for multi-table writes.

### Mermaid Diagram
```mermaid
flowchart TD
  A[BackgroundPaginationService] -->|compute batch| B[(SQLite DB\npagination.sqlite)]
  B -->|UPSERT pages| B
  B -->|UPSERT meta| B
  C[ReaderViewModel] -->|query page N\n(count, meta)| B
  C -->|content or UTF-16 slice| D[PageView]
  E[Settings/View change] -->|compute settings_key| C
  E -->|DELETE stale keys| B
```

### References
- Related architecture: `docs/epic_4/PGN-9-decoupled-pagination.md`, `docs/epic_4/PGN-10.md`
- Layout metrics alignment: `ReadAloudApp/Sources/ReadAloudApp/Utilities/LayoutMetrics.swift`


