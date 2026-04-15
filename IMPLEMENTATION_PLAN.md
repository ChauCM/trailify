# Trailify -- Implementation Plan

This document is the step-by-step build plan for coding agents. Read this file **and** `trailify-spec.md` together. The spec has the full API, data model, and code samples. This plan tells you what to build, in what order, and what files to touch.

## Codebase Context

The repo currently contains the old `logarte` source code under `lib/`. Config files (`pubspec.yaml`, `README.md`, `CHANGELOG.md`) have already been rebranded to `trailify`. The Dart source has not been touched yet.

### Current file structure (lib/)

```
lib/
  logarte.dart                                    # barrel export
  src/
    logarte.dart                                  # Logarte class (main API)
    channels/
      logarte_dio_interceptor.dart                # Dio interceptor
      logarte_navigator_observer.dart             # NavigatorObserver
    console/
      logarte_auth_screen.dart                    # password screen
      logarte_dashboard_screen.dart               # main console UI
      logarte_entry_item.dart                     # list item widget
      logarte_magical_tap.dart                    # hidden gesture trigger
      logarte_overlay.dart                        # floating button overlay
      logarte_theme_wrapper.dart                  # theme wrapper
      network_log_entry_details_screen.dart       # network detail screen
      notification_log_entry_details_screen.dart  # notification detail screen
    extensions/
      entry_extensions.dart
      object_extensions.dart
      route_extensions.dart
      string_extensions.dart
    models/
      logarte_entry.dart                          # LogarteEntry + subtypes
      logarte_type.dart                           # LogarteType enum
      navigation_action.dart
    persistence/
      logarte_persistence.dart                    # abstract persistence
      file_logarte_persistence.dart               # JSONL file persistence
```

### Target file structure (lib/ and test/)

```
lib/
  trailify.dart                                   # barrel export
  src/
    trailify.dart                                 # Trailify singleton class
    trailify_store.dart                           # TrailifyStore (Sembast)
    trailify_identity.dart                        # TrailifyIdentity
    trailify_sync_engine.dart                     # TrailifySyncEngine (Firestore)
    trailify_dio_interceptor.dart                 # TrailifyDioInterceptor
    console/
      trailify_auth_screen.dart                   # password screen (rename, minimal changes)
      trailify_dashboard_screen.dart              # rewritten: unified event list + tabs
      trailify_entry_item.dart                    # rewritten: renders Map<String, dynamic>
      trailify_magical_tap.dart                   # rename, keep behavior
      trailify_overlay.dart                       # rename, keep behavior
      trailify_theme_wrapper.dart                 # rename, keep behavior
      event_detail_screen.dart                    # NEW: generic event detail view
    extensions/
      object_extensions.dart                      # keep as-is
      string_extensions.dart                      # keep as-is
test/
  trailify_store_test.dart                        # local storage scenarios (Phase 3c)
  trailify_dio_interceptor_test.dart              # HTTP capture + scrubbing scenarios (Phase 3c)
  trailify_sync_engine_test.dart                  # Sembast -> Firestore sync scenarios (Phase 3c)
  trailify_integration_test.dart                  # full pipeline end-to-end scenarios (Phase 3c)
```

### Files removed (no longer needed)

```
src/models/logarte_entry.dart          # replaced by Map<String, dynamic> events
src/models/logarte_type.dart           # replaced by string eventType
src/models/navigation_action.dart      # no longer used
src/extensions/entry_extensions.dart   # tied to old entry classes
src/extensions/route_extensions.dart   # no longer used
src/channels/logarte_navigator_observer.dart  # navigation is now manual screenView()
src/persistence/logarte_persistence.dart      # replaced by TrailifyStore
src/persistence/file_logarte_persistence.dart # replaced by TrailifyStore
src/console/network_log_entry_details_screen.dart       # replaced by event_detail_screen
src/console/notification_log_entry_details_screen.dart   # replaced by event_detail_screen
```

---

## Dependencies

Before starting any code, update `pubspec.yaml` to add the new dependencies:

```yaml
dependencies:
  dio: ^5.8.0+1
  flutter:
    sdk: flutter
  sembast: ^3.7.4
  path_provider: ^2.0.11
  shared_preferences: ^2.5.4
  uuid: ^4.5.1
  cloud_firestore: ^6.1.2
  firebase_core: ^4.4.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
  fake_cloud_firestore: ^4.0.0
```

The `fake_cloud_firestore` package provides `FakeFirebaseFirestore` for testing sync without a real Firestore backend. Sembast's in-memory factory (`databaseFactoryMemory`) is already included in the `sembast` package.

Run `flutter pub get` after updating.

---

## Build Order

Each phase is independently testable. Complete one phase before starting the next.

### Phase 1: Core data layer

**Goal**: Events can be created, stored locally in Sembast, and read back.

**Files to create**:

1. **`lib/src/trailify_identity.dart`** -- `TrailifyIdentity` class
   - Spec section: "User Identity Lifecycle"
   - Device ID via SharedPreferences (`trailify_device_id`)
   - Session ID generated on init
   - `setUser()`, `clearUser()`, `envelope()` method
   - `backfillUser()` method
   - Firebase project ID detection (try/catch)

2. **`lib/src/trailify_store.dart`** -- `TrailifyStore` class
   - Spec section: "Local Storage Layer (Sembast)"
   - Copy the class verbatim from the spec
   - Database file: `trailify_audit.db`
   - Store name: `events`
   - Methods: `insert`, `getRecent`, `getPendingSync`, `markSynced`, `markFailed`, `deleteOlderThan`, `syncStatusCounts`, `count`, `close`

3. **`lib/src/trailify.dart`** -- `Trailify` singleton (partial, no sync yet)
   - Spec section: "Trailify Core API"
   - Singleton pattern: `Trailify.instance`
   - `init()` -- creates store, identity, loads recent events, runs cleanup
   - Set `_syncEngine` to null for now (sync comes in Phase 3)
   - `log()` -- core method, writes to in-memory list + Sembast
   - `setUser()`, `clearUser()`
   - Convenience methods: `notification()`, `auth()`, `userAction()`, `screenView()`, `error()`
   - `dispose()`
   - `localOnlyEventTypes` logic: stamp events as `localOnly` or `pending` at creation time

4. **`lib/trailify.dart`** -- barrel export
   - Export `Trailify` class, `TrailifyDioInterceptor` (Phase 2), and console widgets

**Verification**: Write a test or example that calls `Trailify.instance.init()`, logs a few events, and reads them back from `TrailifyStore`. Events should persist across init/close cycles.

---

### Phase 2: Dio interceptor

**Goal**: HTTP requests are auto-captured with scrubbing and body capture controls.

**Files to create**:

1. **`lib/src/trailify_dio_interceptor.dart`** -- `TrailifyDioInterceptor`
   - Spec section: "Dio Interceptor"
   - Copy the class from the spec
   - Constructor params: `excludePatterns`, `alwaysCaptureBodyPatterns`, `maxBodySize` (2000), `captureSuccessBodies` (false)
   - `onRequest` -- stores start time in `options.extra`
   - `onResponse` / `onError` -- calls `_logHttpEvent`
   - `_logHttpEvent` -- determines `api_request` vs `api_error`, decides body capture, calls `_trailify.log()`
   - `_scrubHeaders` -- redacts Authorization, Cookie, Set-Cookie, X-Api-Key
   - `_scrubBody` -- redacts password, token, refreshToken, accessToken, secret, base64
   - `_truncate` -- caps at `_maxBodySize` chars

**Files to delete** (or leave for now and remove in Phase 6):
- `lib/src/channels/logarte_dio_interceptor.dart`

**Verification**: Add `TrailifyDioInterceptor` to a Dio instance, make a request to `jsonplaceholder.typicode.com`, check that an `api_request` event appears in `Trailify.instance.entries`.

---

### Phase 3: Firestore sync engine

**Goal**: Pending events are periodically batch-written to Firestore. Sync is idempotent.

**Files to create**:

1. **`lib/src/trailify_sync_engine.dart`** -- `TrailifySyncEngine`
   - Spec section: "Sync Engine"
   - Copy the class from the spec
   - Periodic timer, `sync()` method
   - Uses `eventId` as Firestore doc ID (idempotent)
   - Strips `syncStatus` before upload
   - Converts ISO timestamp to Firestore `Timestamp`
   - Adds `expiresAt` (event time + 90 days)
   - `start()`, `stop()`, `flush()`

2. **Update `lib/src/trailify.dart`**:
   - Wire `TrailifySyncEngine` into `init()` when `enableSync: true`
   - `_syncEngine` is `TrailifySyncEngine?` (nullable)
   - `clearUser()` calls `_syncEngine?.flush()`
   - `dispose()` calls `_syncEngine?.stop()` then `_syncEngine?.flush()`

**Verification**: Initialize with `enableSync: true`, log some events, call `_syncEngine.flush()`, check Firestore Console for documents in `event_logs` collection with correct structure.

---

### Phase 3b: Testability refactor

**Goal**: Make all core components testable without a device, emulator, or native plugins. This is a refactor of existing code -- no new features, no behavior changes.

**Why now**: Phases 1-3 are complete. Before building more features (overlay, cleanup), we add the injection points so every subsequent phase can be verified with automated tests. This is a one-time cost that pays off for every future phase.

**Update `pubspec.yaml`**:
- Add `fake_cloud_firestore: ^4.0.0` to `dev_dependencies`
- Sembast's `databaseFactoryMemory` is already included in the `sembast` package, no extra dependency needed

**Files to modify**:

1. **`lib/src/trailify_store.dart`** -- add injectable constructor
   - Spec section: "Testability > Injection Points > TrailifyStore"
   - Add fields: `final DatabaseFactory _dbFactory` and `final String? _dbPath`
   - Keep the existing no-arg constructor as `TrailifyStore()` -- defaults to `databaseFactoryIo` + `null` path (uses `path_provider` at runtime)
   - Add `TrailifyStore.withFactory(DatabaseFactory dbFactory, String dbPath)` -- test constructor
   - Update `_openDb()` to use `_dbFactory` and `_dbPath` (fall back to `path_provider` when `_dbPath` is null)
   - Import `package:sembast/sembast.dart` (for `DatabaseFactory` type) -- already imported

2. **`lib/src/trailify_identity.dart`** -- add test init method
   - Spec section: "Testability > Injection Points > TrailifyIdentity"
   - Add `initForTest()` method that sets all fields directly without `SharedPreferences` or `Firebase.app()`
   - Add `String? get sessionId => _sessionId` getter (needed by tests to verify backfill)
   - Keep `init()` unchanged for production

3. **`lib/src/trailify.dart`** -- add test init and reset
   - Spec section: "Testability > Injection Points > Trailify"
   - Change `late final TrailifyStore _store` to `late TrailifyStore _store` (remove `final` so it can be set in both init paths)
   - Change `late final TrailifyIdentity _identity` to `late TrailifyIdentity _identity`
   - Add `TrailifyStore get store => _store` getter
   - Add `initForTest()` method -- accepts pre-built `TrailifyStore`, `TrailifyIdentity`, optional `TrailifySyncEngine`, skips all platform plugin calls
   - Add `resetForTest()` method -- stops sync, clears `_initialized` flag, empties `entries.value`

**Files unchanged**: `TrailifySyncEngine` already accepts `FirebaseFirestore?` in constructor -- no changes needed. `TrailifyDioInterceptor` has no platform dependencies -- no changes needed.

**Verification**: `flutter analyze` passes. Existing behavior is unchanged -- the default constructors still work exactly as before. The new constructors/methods are only used by tests.

---

### Phase 3c: Scenario tests

**Goal**: Automated test suite that verifies the full data pipeline using in-memory fakes. Run with `flutter test`.

**Spec section**: "Testability > Scenario Test Structure" and "Testability > Test Helper Pattern"

**Files to create**:

1. **`test/trailify_store_test.dart`** -- local storage scenarios
   - Uses `TrailifyStore.withFactory(newDatabaseFactoryMemory(), 'test.db')`
   - Scenarios:
     - Events persist across reads
     - Pending events are queryable for sync (mix pending/localOnly/synced)
     - Retention policy deletes old events
     - Mark synced updates status
     - Pre-auth backfill updates userId

2. **`test/trailify_dio_interceptor_test.dart`** -- HTTP capture + scrubbing scenarios
   - Uses a real `Trailify.instance` initialized via `initForTest()` with in-memory store
   - Attaches `TrailifyDioInterceptor` to a Dio instance with a mock HTTP adapter
   - Scenarios:
     - Successful GET produces api_request event
     - Failed POST produces api_error event
     - Sensitive headers are redacted
     - Sensitive body fields are redacted
     - Excluded URL patterns produce no events
     - Body capture respects captureSuccessBodies flag
     - alwaysCaptureBodyPatterns overrides the default
     - Large bodies are truncated

3. **`test/trailify_sync_engine_test.dart`** -- Sembast to Firestore sync scenarios
   - Uses `TrailifyStore.withFactory(...)` + `FakeFirebaseFirestore()`
   - Scenarios:
     - Pending events sync to Firestore
     - Synced events are marked locally
     - Idempotent sync (no duplicate docs)
     - localOnly events never sync
     - syncStatus stripped from Firestore doc
     - Timestamp converted to Firestore Timestamp
     - expiresAt set correctly

4. **`test/trailify_integration_test.dart`** -- full pipeline end-to-end scenarios
   - Uses `Trailify.instance.initForTest(...)` with all in-memory fakes
   - Scenarios:
     - Full audit trail for "message send" (log -> store -> sync -> Firestore)
     - Pre-auth events get backfilled on setUser()
     - localOnly event types stay local after sync
     - clearUser flushes pending events
     - In-memory list capped at memoryLimit

**Each test file uses the setUp/tearDown pattern from the spec** -- fresh `newDatabaseFactoryMemory()`, fresh `FakeFirebaseFirestore()`, `Trailify.instance.resetForTest()` between tests.

**Verification**: `flutter test` runs all tests and passes. Tests execute in seconds without a device or emulator.

---

### Phase 4: Debug overlay (console UI)

**Goal**: In-app console shows all event types in a unified list with filtering.

This is the largest UI phase. The existing console code can be adapted.

**Files to rename and adapt** (keep the overlay/auth/theme infrastructure):

1. **`lib/src/console/trailify_overlay.dart`** -- rename from `logarte_overlay.dart`
   - Change class names from `LogarteOverlay` to `TrailifyOverlay`
   - Reference `Trailify` instead of `Logarte`

2. **`lib/src/console/trailify_auth_screen.dart`** -- rename from `logarte_auth_screen.dart`
   - Change class names, keep password behavior

3. **`lib/src/console/trailify_theme_wrapper.dart`** -- rename from `logarte_theme_wrapper.dart`
   - Change class names

4. **`lib/src/console/trailify_magical_tap.dart`** -- rename from `logarte_magical_tap.dart`
   - Change class names

**Files to rewrite**:

5. **`lib/src/console/trailify_dashboard_screen.dart`** -- rewrite
   - Spec section: "Debug Overlay"
   - Tab structure: `[All] [API] [Notifications] [Actions] [Auth] [Errors]`
   - Each tab filters `Trailify.instance.entries` by `eventType`
   - Sync status badge showing pending count
   - Search across payload content
   - Data source: `ValueNotifier<List<Map<String, dynamic>>>` from `Trailify.instance.entries`

6. **`lib/src/console/trailify_entry_item.dart`** -- rewrite
   - Renders a `Map<String, dynamic>` event
   - Shows: eventType icon (color-coded), timestamp, summary line
   - Tap opens `EventDetailScreen`

7. **`lib/src/console/event_detail_screen.dart`** -- NEW
   - Generic detail view for any event type
   - Shows envelope fields at top (userId, deviceId, sessionId, platform, etc.)
   - Shows payload as formatted key-value pairs
   - For `api_request`/`api_error`: show method, URL, status, duration, headers, body
   - For `notification_*`: show title, body, topic, messageId
   - Copy button for sharing

**Files to delete**:
- `lib/src/console/network_log_entry_details_screen.dart`
- `lib/src/console/notification_log_entry_details_screen.dart`
- `lib/src/console/logarte_entry_item.dart`
- `lib/src/console/logarte_dashboard_screen.dart`
- `lib/src/console/logarte_overlay.dart`
- `lib/src/console/logarte_auth_screen.dart`
- `lib/src/console/logarte_theme_wrapper.dart`
- `lib/src/console/logarte_magical_tap.dart`

**Verification**: Open the console, see logged events from Phases 1-3, filter by tab, tap to see detail, search works.

---

### Phase 5: Wire up Trailify.openConsole()

**Goal**: `Trailify.instance.openConsole(context)` opens the new console.

**Update `lib/src/trailify.dart`**:
- Implement `openConsole()` to push `TrailifyAuthScreen` (which leads to `TrailifyDashboardScreen`)
- Keep password protection behavior from old code
- Add constructor params: `password`, `ignorePassword`, `onShare`

**Update `lib/trailify.dart`** barrel export:
- Export: `Trailify`, `TrailifyDioInterceptor`, `TrailifyMagicalTap`
- Do NOT export: `TrailifyStore`, `TrailifyIdentity`, `TrailifySyncEngine` (internal)

---

### Phase 6: Cleanup

**Goal**: Remove all old logarte source files, ensure no dead code.

**Delete all remaining old files**:
```
lib/src/logarte.dart
lib/src/channels/logarte_dio_interceptor.dart
lib/src/channels/logarte_navigator_observer.dart
lib/src/models/logarte_entry.dart
lib/src/models/logarte_type.dart
lib/src/models/navigation_action.dart
lib/src/persistence/logarte_persistence.dart
lib/src/persistence/file_logarte_persistence.dart
lib/src/extensions/entry_extensions.dart
lib/src/extensions/route_extensions.dart
lib/logarte.dart
```

**Delete empty directories**:
```
lib/src/channels/
lib/src/models/
lib/src/persistence/
```

**Keep**:
```
lib/src/extensions/object_extensions.dart    # prettyJson extension, still useful
lib/src/extensions/string_extensions.dart    # if used by console
```

**Update example app** (`example/lib/main.dart`):
- Rewrite to use `Trailify.instance.init()`, `TrailifyDioInterceptor`, `Trailify.instance.openConsole()`
- Remove old Logarte references

**Run**:
- `flutter analyze` -- fix any warnings
- `flutter test` -- all scenario tests from Phase 3c must still pass

---

## Rules for Coding Agents

1. **The spec is the source of truth.** If this plan and the spec disagree, follow the spec.
2. **Copy code from the spec.** The spec contains complete, tested-in-design code for `TrailifyStore`, `TrailifyIdentity`, `TrailifySyncEngine`, `TrailifyDioInterceptor`, and `Trailify`. Use it directly.
3. **Events are `Map<String, dynamic>`, not typed classes.** The old code used `LogarteEntry` subclasses. The new code uses plain maps. Do not create entry classes.
4. **One phase at a time.** Complete and verify each phase before moving to the next.
5. **Do not modify `trailify-spec.md` or `IMPLEMENTATION_PLAN.md`.**
6. **Do not add comments that narrate what the code does.** Only add comments for non-obvious intent.
7. **Keep the `dio` dependency.** It's already in `pubspec.yaml`. Do not remove it.
8. **The Trailify class is a singleton with injectable internals.** `Trailify.instance` is the only way to access it. Production code uses `init()` (default constructors for store/identity). Test code uses `initForTest()` with pre-built dependencies. Both init paths set the same internal state -- the rest of the class does not know or care which path was used.
9. **Null-safe sync engine.** `_syncEngine` is `TrailifySyncEngine?`. Always use `_syncEngine?.method()`. Never force-unwrap.
10. **Fire-and-forget inserts.** `_store.insert(entry)` is called without `await` in `log()`. This is intentional -- logging must never block the app.
11. **Tests use real in-memory databases, not hand-rolled mocks.** Use `databaseFactoryMemory` for Sembast and `FakeFirebaseFirestore` for Firestore. These implement the real APIs with real query/filter/sort behavior.
12. **Each test gets fresh state.** Call `newDatabaseFactoryMemory()` (not the shared `databaseFactoryMemory` singleton), create a fresh `FakeFirebaseFirestore()`, and call `Trailify.instance.resetForTest()` in setUp. No test should depend on state from another test.
13. **Test scenarios, not methods.** Each test should represent a real user scenario or a real debugging scenario from the spec. Do not write tests that verify a single method in isolation.
