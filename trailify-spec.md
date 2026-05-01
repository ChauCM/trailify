# Trailify -- Technical Specification

## Overview

Trailify is an **offline-first audit trail** for Flutter apps with Firestore sync. Every meaningful event in the app -- API calls, notifications, user actions, auth events, errors -- is captured locally in a document store (Sembast), displayed in a debug overlay, and synced to Cloud Firestore for remote investigation.

The primary use case is **operational debugging**: when a user reports "my message disappeared" or "I didn't receive a notification," you query Firestore by their user ID and see exactly what happened, step by step, with API request/response evidence.

### Primary Query Pattern

**"Show me everything user X did."**

All design decisions flow from this. The cloud data model is optimized for: filter by `userId`, sort by `timestamp` descending, optionally filter by `eventType`.

### What This Replaces

- The notification-specific Firestore logging spec (`docs/notification-firestore-logging.md`) -- notification events become one event type among many
- The notification tab spec (`docs/logarte-notification-tab-spec.md`) -- the debug overlay shows all event types, including notifications
- The existing `TrailifyDioInterceptor` -- replaced with `TrailifyDioInterceptor` that captures request/response bodies

## Architecture

```
┌─────────────────────────────────────────────┐
│                  App Code                   │
│                                             │
│  Trailify.instance.network(...)              │
│  Trailify.instance.notification(...)         │
│  Trailify.instance.userAction(...)           │
│  Trailify.instance.auth(...)                 │
│  Trailify.instance.error(...)                │
│                                             │
│  TrailifyDioInterceptor (auto-captures HTTP)   │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│             Trailify Core                   │
│                                             │
│  ┌─────────────┐     ┌──────────────────┐   │
│  │  In-Memory   │     │   Sembast DB     │   │
│  │  (overlay    │     │   (persistent)   │   │
│  │   display)   │     │                  │   │
│  └─────────────┘     └────────┬─────────┘   │
│                               │              │
│                        ┌──────▼──────┐       │
│                        │ Sync Engine │       │
│                        └──────┬──────┘       │
└───────────────────────────────┼──────────────┘
                                │
                     ┌──────────▼──────────┐
                     │  Cloud Firestore    │
                     │  event_logs         │
                     │  collection         │
                     └─────────────────────┘
```

### Data Flow

1. App code calls a log method (or the Dio interceptor fires automatically)
2. Trailify creates a `TrailifyEntry` (a `Map<String, dynamic>`)
3. The entry is written to:
   - **In-memory list** (for the debug overlay, capped at N entries)
   - **Sembast local DB** (persistent, survives app restart)
4. The sync engine periodically picks up entries with `syncStatus: pending` and batch-writes them to Firestore
5. On successful sync, entries are marked `synced` locally
6. Local retention policy deletes entries older than the configured TTL

### Why Sembast

Event logs are semi-structured documents: a common envelope (timestamp, userId, eventType) with a variable payload per event type. This is document data, not relational data.

Sembast is a pure-Dart document store. The local document (a `Map<String, dynamic>`) is the same shape as the Firestore document. No serialization layer, no ORM, no SQL schema migrations, no JSON text columns. Write a Map locally, send the same Map to Firestore.

Additional benefits:
- No native dependencies (pure Dart) -- keeps trailify lightweight as an open source package
- No code generation required
- Stable and maintained since 2018

Note: Sembast uses `sembast_io` and `path_provider` which are native-only (iOS/Android). If web support is ever needed, swap to `sembast_web`.

## Event Model

### Entry Envelope

Every event shares this structure:

```dart
{
  // Identity
  'deviceId': 'a1b2c3d4-...',          // persistent UUID, set before login
  'userId': 'USR_100042',        // set after login, null before
  'userEmail': 'user@example.com',    // set after login, null before
  'appId': 'app_one',                   // identifies which app produced the event
  'appFlavor': 'prod',

  // Event metadata
  'eventId': 'evt-uuid-v4-...',         // unique ID, used as Firestore doc ID for idempotent sync
  'eventType': 'api_request',           // discriminator
  'timestamp': '2026-04-24T10:42:03.123Z',
  'sessionId': 'sess-uuid-...',         // groups events within one app session

  // Device context
  'platform': 'ios',                    // 'ios' or 'android'
  'appVersion': '1.22.9',

  // Sync state (local only, stripped before upload)
  'syncStatus': 'pending',             // 'pending' | 'synced' | 'localOnly' | 'failed'

  // Event-specific data
  'payload': { ... }                   // varies by eventType
}
```

### Event Types and Payloads

#### `api_request` -- HTTP request/response (auto-captured by Dio interceptor)

```dart
'payload': {
  'method': 'POST',
  'url': '/api/v1/conversation/message',
  'baseUrl': 'https://api.example.com',
  'requestHeaders': { 'Content-Type': 'application/json' },
  'requestBody': { 'message': '...', 'conversationId': 42 },
  'statusCode': 200,
  'responseBody': { 'id': 999, 'message': '...' },  // truncated if large
  'durationMs': 342,
  'error': null,                   // populated on failure
  'errorType': null,               // 'timeout', 'connection', 'badResponse', etc.
}
```

#### `api_error` -- HTTP request that failed (Dio error, timeout, network error)

```dart
'payload': {
  'method': 'POST',
  'url': '/api/v1/conversation/message',
  'baseUrl': 'https://api.example.com',
  'requestBody': { ... },
  'statusCode': 500,               // null for timeouts/network errors
  'responseBody': { ... },         // null for timeouts/network errors
  'durationMs': 30000,
  'error': 'Connection timeout',
  'errorType': 'timeout',
}
```

#### `notification_received` -- push notification delivered to device

```dart
'payload': {
  'messageId': '0:1776937819867824%6ca622006ca62200',
  'title': 'A new Moments post has been published.',
  'body': 'Check out the latest update for your child.',
  'topic': 'updates_USR_100042',
  'data': { 'type': 'post', 'postId': '123' },
  'source': 'foreground',          // 'foreground' | 'background'
}
```

#### `notification_tapped` -- user tapped on a notification

```dart
'payload': {
  'messageId': '...',
  'title': '...',
  'body': '...',
  'topic': '...',
  'data': { ... },
  'source': 'background',          // 'background' | 'terminated' | 'local'
}
```

#### `notification_subscribed` / `notification_unsubscribed` -- topic subscription changes

```dart
'payload': {
  'topic': 'account-USR_100042',
}
```

#### `auth_login` -- login attempt

```dart
'payload': {
  'method': 'keycloak',            // 'keycloak' | 'email_password' | 'biometric'
  'success': true,
  'error': null,                   // error message on failure
  'email': 'user@example.com',   // available even pre-auth
}
```

#### `auth_logout` -- user logged out

```dart
'payload': {
  'reason': 'user_initiated',      // 'user_initiated' | 'token_expired' | 'forced'
}
```

#### `auth_token_refresh` -- token refresh attempt

```dart
'payload': {
  'success': true,
  'error': null,
}
```

#### `screen_viewed` -- user navigated to a screen

```dart
'payload': {
  'screenName': 'ConversationChatPage',
  'arguments': { 'conversationId': 42 },  // optional, scrubbed of PII
}
```

#### `user_action` -- explicit user action at a key point

```dart
'payload': {
  'action': 'send_message',
  'context': {
    'conversationId': 42,
    'hasImages': true,
    'imageCount': 2,
    'hasFiles': false,
    'textLength': 156,
  },
}
```

#### `error` -- caught exception

```dart
'payload': {
  'error': 'FormatException: Unexpected character',
  'stackTrace': '...',            // first 500 chars
  'context': 'MessageComposerCubit.uploadImages',
}
```

## Local Storage Layer (Sembast)

### Database Setup

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TrailifyStore {
  static const _dbName = 'trailify_audit.db';
  static const _storeName = 'events';

  final DatabaseFactory _dbFactory;
  final String? _dbPath;

  Database? _db;
  final _store = intMapStoreFactory.store(_storeName);

  /// Production constructor -- uses databaseFactoryIo + path_provider.
  TrailifyStore() : _dbFactory = databaseFactoryIo, _dbPath = null;

  /// Test constructor -- accepts any DatabaseFactory and a fixed path.
  /// Use with databaseFactoryMemory for in-memory tests.
  TrailifyStore.withFactory(this._dbFactory, this._dbPath);

  Future<Database> get db async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    if (_dbPath != null) {
      return _dbFactory.openDatabase(_dbPath!);
    }
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);
    return _dbFactory.openDatabase(dbPath);
  }

  /// Insert an event. Returns the record key.
  Future<int> insert(Map<String, dynamic> entry) async {
    final database = await db;
    return _store.add(database, entry);
  }

  /// Get recent events for the debug overlay.
  Future<List<RecordSnapshot<int, Map<String, dynamic>>>> getRecent({
    int limit = 200,
    String? eventTypeFilter,
  }) async {
    final database = await db;
    final finder = Finder(
      sortOrders: [SortOrder('timestamp', false)],
      limit: limit,
    );
    if (eventTypeFilter != null) {
      finder.filter = Filter.equals('eventType', eventTypeFilter);
    }
    return _store.find(database, finder: finder);
  }

  /// Get pending events for sync.
  Future<List<RecordSnapshot<int, Map<String, dynamic>>>> getPendingSync({
    int limit = 500,
  }) async {
    final database = await db;
    return _store.find(
      database,
      finder: Finder(
        filter: Filter.equals('syncStatus', 'pending'),
        sortOrders: [SortOrder('timestamp', true)],
        limit: limit,
      ),
    );
  }

  /// Mark entries as synced.
  Future<void> markSynced(List<int> keys) async {
    final database = await db;
    await database.transaction((txn) async {
      for (final key in keys) {
        await _store.record(key).update(txn, {'syncStatus': 'synced'});
      }
    });
  }

  /// Mark entries as failed.
  Future<void> markFailed(List<int> keys) async {
    final database = await db;
    await database.transaction((txn) async {
      for (final key in keys) {
        await _store.record(key).update(txn, {'syncStatus': 'failed'});
      }
    });
  }

  /// Delete events older than the retention period.
  Future<int> deleteOlderThan(DateTime cutoff) async {
    final database = await db;
    final filter = Filter.lessThan('timestamp', cutoff.toIso8601String());
    return _store.delete(database, finder: Finder(filter: filter));
  }

  /// Count events by sync status (for diagnostics).
  Future<Map<String, int>> syncStatusCounts() async {
    final database = await db;
    final pending = await _store.count(
      database,
      filter: Filter.equals('syncStatus', 'pending'),
    );
    final synced = await _store.count(
      database,
      filter: Filter.equals('syncStatus', 'synced'),
    );
    final failed = await _store.count(
      database,
      filter: Filter.equals('syncStatus', 'failed'),
    );
    return {'pending': pending, 'synced': synced, 'failed': failed};
  }

  /// Total event count.
  Future<int> count() async {
    final database = await db;
    return _store.count(database);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
```

### Retention Policy

- **Local retention**: 7 days. Events older than 7 days are deleted regardless of sync status.
- **Cleanup runs on startup** and every 6 hours while the app is running.
- **In-memory cap**: 500 entries for the debug overlay (most recent). The overlay reads from Sembast on init, then appends new events in real-time.

### Database Size Estimate

- Average event size: ~500 bytes as JSON
- 5 notifications/day + 50 API calls/day + 20 user actions/day + misc = ~100 events/day
- 7 days retention = ~700 events = ~350 KB
- Well within acceptable limits for local storage.

## User Identity Lifecycle

### The Problem

Events happen before and after login. A parent might fail to log in (pre-auth), and we need to track that. After login, we need to tag events with the user's identity. On logout, we stop tagging but don't stop logging.

### Device ID (Always Available)

On first app launch, generate a UUID v4 and store it in SharedPreferences. This persists across sessions and survives logout/login cycles.

```dart
class TrailifyIdentity {
  String? _deviceId;
  String? _userId;
  String? _userEmail;
  String? _appId;
  String? _appFlavor;
  String? _appVersion;
  String? _sessionId;
  String? _platform;
  String? _firebaseProject;

  /// Call once on app startup, before anything else.
  /// Uses SharedPreferences for persistent deviceId and Firebase for project detection.
  Future<void> init({
    required String appFlavor,
    required String appVersion,
    required String platform,
  }) async {
    _appFlavor = appFlavor;
    _appVersion = appVersion;
    _platform = platform;
    _sessionId = _generateUuid();

    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('trailify_device_id');
    if (_deviceId == null) {
      _deviceId = _generateUuid();
      await prefs.setString('trailify_device_id', _deviceId!);
    }

    try {
      _firebaseProject = Firebase.app().options.projectId;
    } catch (_) {}
  }

  /// Test-only initializer -- sets all fields directly, no SharedPreferences or Firebase needed.
  /// Runs entirely in-memory with deterministic values.
  void initForTest({
    required String deviceId,
    required String sessionId,
    String appFlavor = 'test',
    String appVersion = '0.0.1',
    String platform = 'ios',
    String? firebaseProject,
  }) {
    _deviceId = deviceId;
    _sessionId = sessionId;
    _appFlavor = appFlavor;
    _appVersion = appVersion;
    _platform = platform;
    _firebaseProject = firebaseProject;
  }

  String? get sessionId => _sessionId;

  /// Call after successful login.
  void setUser({
    required String userId,
    required String email,
    required String appId,
  }) {
    _userId = userId;
    _userEmail = email;
    _appId = appId;
  }

  /// Call on logout.
  void clearUser() {
    _userId = null;
    _userEmail = null;
    _appId = null;
    // deviceId and sessionId persist
  }

  /// Build the envelope fields for an event.
  /// [syncStatus] controls whether the event will be synced to Firestore.
  /// Use 'pending' for syncable events, 'localOnly' for events that stay on device.
  Map<String, dynamic> envelope({String syncStatus = 'pending'}) {
    return {
      'eventId': _generateUuid(),
      'deviceId': _deviceId,
      'userId': _userId,
      'userEmail': _userEmail,
      'appId': _appId,
      'appFlavor': _appFlavor,
      'platform': _platform,
      'appVersion': _appVersion,
      'sessionId': _sessionId,
      'firebaseProject': _firebaseProject,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'syncStatus': syncStatus,
    };
  }

  String _generateUuid() {
    // Use the `uuid` package
    return const Uuid().v4();
  }
}
```

### Backfill on Login

When `setUser()` is called, backfill the `userId` and `userEmail` onto recent events from the current session that don't have a userId yet:

```dart
/// Backfill user identity onto pre-auth events from this session.
Future<void> backfillUser(TrailifyStore store) async {
  if (_userId == null || _sessionId == null) return;

  final database = await store.db;
  final preAuthEvents = await store._store.find(
    database,
    finder: Finder(
      filter: Filter.and([
        Filter.equals('sessionId', _sessionId),
        Filter.isNull('userId'),
      ]),
    ),
  );

  await database.transaction((txn) async {
    for (final record in preAuthEvents) {
      await store._store.record(record.key).update(txn, {
        'userId': _userId,
        'userEmail': _userEmail,
        'appId': _appId,
      });
    }
  });
}
```

This means if a parent enters their email, fails to log in, and reports the issue -- you can still find those events by deviceId or (after successful login) by userId.

### Handling Mixed Account ID Types

Some apps use `String` accountId (e.g., `"USR_202000125017"`), others use `int` accountId (e.g., `12345`). The `userId` field in the audit trail is always stored as a `String`. Int-based callers convert via `.toString()`.

## Dio Interceptor

Replaces the existing `TrailifyDioInterceptor`. Auto-captures every HTTP request and response.

```dart
class TrailifyDioInterceptor extends Interceptor {
  final Trailify _trailify;

  /// Max size (in characters) for request/response body capture.
  /// 2000 chars balances debuggability with storage cost.
  final int _maxBodySize;

  /// Whether to capture request/response bodies for successful requests.
  /// When false (default), bodies are only captured for errors (status >= 400
  /// or Dio exceptions). This significantly reduces Firestore storage.
  /// When true, all request/response bodies are captured (useful for
  /// debugging specific endpoints like conversation message send).
  final bool _captureSuccessBodies;

  /// URL path patterns to exclude from logging (e.g., token endpoints).
  final List<RegExp> _excludePatterns;

  /// URL path patterns to ALWAYS capture bodies for, even when
  /// _captureSuccessBodies is false. Use for critical debugging targets.
  final List<RegExp> _alwaysCaptureBodyPatterns;

  /// Header keys to redact (values replaced with '[REDACTED]').
  static const _sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
  };

  /// Request body field keys to redact.
  static const _sensitiveBodyFields = {
    'password',
    'token',
    'refreshToken',
    'refreshtoken',
    'accessToken',
    'secret',
    'base64',      // file upload content -- too large, not useful for debugging
  };

  TrailifyDioInterceptor(
    this._trailify, {
    List<RegExp>? excludePatterns,
    List<RegExp>? alwaysCaptureBodyPatterns,
    int maxBodySize = 2000,
    bool captureSuccessBodies = false,
  }) : _excludePatterns = excludePatterns ?? [],
       _alwaysCaptureBodyPatterns = alwaysCaptureBodyPatterns ?? [],
       _maxBodySize = maxBodySize,
       _captureSuccessBodies = captureSuccessBodies;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_auditStartTime'] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logHttpEvent(
      options: response.requestOptions,
      statusCode: response.statusCode,
      responseBody: response.data,
      error: null,
      errorType: null,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logHttpEvent(
      options: err.requestOptions,
      statusCode: err.response?.statusCode,
      responseBody: err.response?.data,
      error: err.message ?? err.toString(),
      errorType: err.type.name,
    );
    handler.next(err);
  }

  void _logHttpEvent({
    required RequestOptions options,
    required int? statusCode,
    required dynamic responseBody,
    required String? error,
    required String? errorType,
  }) {
    // Check exclusions
    final path = options.uri.path;
    if (_excludePatterns.any((re) => re.hasMatch(path))) return;

    final startTime = options.extra['_auditStartTime'] as int?;
    final durationMs = startTime != null
        ? DateTime.now().millisecondsSinceEpoch - startTime
        : null;

    final isError = error != null || (statusCode != null && statusCode >= 400);
    final eventType = isError ? 'api_error' : 'api_request';

    // Decide whether to capture bodies for this request.
    // Always capture for errors. For successes, only capture if globally
    // enabled or if the URL matches an always-capture pattern.
    final shouldCaptureBodies = isError ||
        _captureSuccessBodies ||
        _alwaysCaptureBodyPatterns.any((re) => re.hasMatch(path));

    _trailify.log(
      eventType: eventType,
      payload: {
        'method': options.method,
        'url': options.path,
        'baseUrl': options.baseUrl,
        'requestHeaders': _scrubHeaders(options.headers),
        if (shouldCaptureBodies)
          'requestBody': _scrubBody(_truncate(options.data)),
        'statusCode': statusCode,
        if (shouldCaptureBodies)
          'responseBody': _truncate(responseBody),
        'durationMs': durationMs,
        'error': error,
        'errorType': errorType,
      },
    );
  }

  Map<String, dynamic> _scrubHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      if (_sensitiveHeaders.contains(key.toLowerCase())) {
        return MapEntry(key, '[REDACTED]');
      }
      return MapEntry(key, value?.toString());
    });
  }

  dynamic _scrubBody(dynamic body) {
    if (body is Map) {
      return body.map((key, value) {
        if (_sensitiveBodyFields.contains(key.toString().toLowerCase())) {
          return MapEntry(key, '[REDACTED]');
        }
        if (value is Map) return MapEntry(key, _scrubBody(value));
        return MapEntry(key, value);
      });
    }
    return body;
  }

  dynamic _truncate(dynamic body) {
    if (body == null) return null;
    if (body is String && body.length > _maxBodySize) {
      return '${body.substring(0, _maxBodySize)}... [TRUNCATED]';
    }
    if (body is Map || body is List) {
      final jsonStr = body.toString();
      if (jsonStr.length > _maxBodySize) {
        return '${jsonStr.substring(0, _maxBodySize)}... [TRUNCATED]';
      }
    }
    return body;
  }
}
```

### What Gets Captured Automatically

Every Dio request/response. Add the interceptor wherever you create a Dio instance:

```dart
dio.interceptors.add(TrailifyDioInterceptor(Trailify.instance));
```

### Real-World Debugging Example: "My message disappeared"

With this interceptor, when a parent reports a disappeared message, you query Firestore for their userId and see:

1. `screen_viewed` -- ConversationChatPage, conversationId: 42
2. `user_action` -- send_message, textLength: 156, hasImages: true
3. `api_request` -- POST /api/v1/file, statusCode: 200, response: `{ url: "..." }`
4. `api_request` -- POST /api/v1/conversation/message, statusCode: 200, response: `{ id: 999, message: "..." }`

If the API returned 200 and the response contains the message, the backend accepted it. The message "disappearing" is a backend/database issue, not a mobile issue. Evidence secured.

If instead you see:

3. `api_error` -- POST /api/v1/conversation/message, statusCode: 500, error: "Internal Server Error"

Then the message was never accepted. Different problem, different conversation with backend.

## Sync Engine

### Design Principles

- **Fire-and-forget from the caller's perspective** -- logging never blocks the app
- **Connectivity-aware** -- don't attempt sync when offline
- **Batched** -- Firestore batch writes, max 500 docs per batch
- **Retry with backoff** -- failed syncs retry with exponential backoff
- **Configurable** -- control which event types sync to the cloud

### Implementation

```dart
class TrailifySyncEngine {
  final TrailifyStore _store;
  final FirebaseFirestore _firestore;
  final String _collection;

  Timer? _syncTimer;
  bool _isSyncing = false;

  /// Sync interval.
  final Duration _syncInterval;

  /// Fields to strip before uploading (local-only metadata).
  static const _localOnlyFields = {'syncStatus'};

  TrailifySyncEngine({
    required TrailifyStore store,
    FirebaseFirestore? firestore,
    String collection = 'event_logs',
    Duration syncInterval = const Duration(minutes: 2),
  })  : _store = store,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _collection = collection,
        _syncInterval = syncInterval;

  /// Start periodic sync.
  void start() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => sync());
    // Run one sync immediately on start
    sync();
  }

  /// Stop periodic sync.
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Run a single sync cycle.
  ///
  /// Only picks up events with syncStatus == 'pending'. Events marked
  /// 'localOnly' at creation time are never queried here.
  ///
  /// Uses eventId as the Firestore document ID. This makes sync idempotent:
  /// if batch.commit() succeeds but markSynced() fails (app killed, Sembast
  /// error), the next cycle re-uploads the same events but they overwrite
  /// the same Firestore documents instead of creating duplicates.
  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingRecords = await _store.getPendingSync(limit: 500);
      if (pendingRecords.isEmpty) return;

      // Firestore batch write (max 500 per batch)
      final batch = _firestore.batch();
      final keys = <int>[];

      for (final record in pendingRecords) {
        final doc = Map<String, dynamic>.from(record.value);

        // Extract eventId for use as Firestore doc ID
        final eventId = doc['eventId'] as String?;
        if (eventId == null) continue;

        // Strip local-only fields
        for (final field in _localOnlyFields) {
          doc.remove(field);
        }

        // Convert ISO string timestamp to Firestore Timestamp
        if (doc['timestamp'] is String) {
          doc['timestamp'] = Timestamp.fromDate(
            DateTime.parse(doc['timestamp'] as String),
          );
        }

        // Add TTL expiry (90 days from event time)
        final eventTime = doc['timestamp'] is Timestamp
            ? (doc['timestamp'] as Timestamp).toDate()
            : DateTime.now();
        doc['expiresAt'] = Timestamp.fromDate(
          eventTime.add(const Duration(days: 90)),
        );

        // Use eventId as doc ID for idempotent writes
        final docRef = _firestore.collection(_collection).doc(eventId);
        batch.set(docRef, doc);
        keys.add(record.key);
      }

      await batch.commit();
      await _store.markSynced(keys);
    } catch (e) {
      // On failure, events remain 'pending' and will be retried next cycle.
      // Firestore errors are expected when offline -- don't log them
      // aggressively to avoid recursive logging.
      debugPrint('TrailifySyncEngine: sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Force an immediate sync (e.g., on logout).
  Future<void> flush() async {
    await sync();
  }
}
```

### Sync Behavior

| Scenario | Behavior |
|---|---|
| App online, normal operation | Syncs every 2 minutes |
| App offline | Sync silently fails, events accumulate locally, sync succeeds when back online |
| App backgrounded | Timer stops (Flutter pauses timers). Syncs on next resume. |
| User logs out | `flush()` called to push remaining events before clearing user context |
| App killed / crashes | Events persist in Sembast. Synced on next launch. |
| Sync fails mid-batch | Entire batch stays `pending`, retried next cycle. Uses eventId as Firestore doc ID so retries are idempotent (no duplicates). |

### What Syncs vs What Stays Local

Sync eligibility is determined **at event creation time**, not at sync time. Events are stamped with either `syncStatus: 'pending'` (will sync) or `syncStatus: 'localOnly'` (stays on device). This avoids the problem of excluded events clogging the sync query forever.

The `localOnlyEventTypes` config on `Trailify.init()` controls this:

```dart
await Trailify.instance.init(
  // ...
  localOnlyEventTypes: {'screen_viewed'},  // these get syncStatus: 'localOnly' on insert
);
```

All other event types get `syncStatus: 'pending'` and will be picked up by the sync engine. The sync query (`WHERE syncStatus == 'pending'`) never touches `localOnly` events.

Default: **everything syncs** (no `localOnlyEventTypes`). Recommended starting config:

```dart
localOnlyEventTypes: {'screen_viewed'},  // keep screen views local-only to reduce cloud volume
```

## Trailify Core API

### Initialization

```dart
class Trailify {
  static final Trailify instance = Trailify._();
  Trailify._();

  late TrailifyStore _store;
  late TrailifyIdentity _identity;
  TrailifySyncEngine? _syncEngine;    // nullable -- null when enableSync: false

  /// In-memory entries for the debug overlay.
  final ValueNotifier<List<Map<String, dynamic>>> entries =
      ValueNotifier([]);

  /// Max in-memory entries.
  int _memoryLimit = 500;

  /// Event types that are local-only (never synced to Firestore).
  Set<String> _localOnlyEventTypes = {};

  bool _initialized = false;

  /// Expose store for internal use (backfill, sync engine, tests).
  TrailifyStore get store => _store;

  /// Initialize the audit trail.
  ///
  /// Call once during app startup, before any logging.
  /// [enableSync] -- set false for debug/test builds to skip Firestore writes.
  /// [syncInterval] -- how often to push to Firestore.
  /// [localOnlyEventTypes] -- event types that stay on device (never synced).
  /// [memoryLimit] -- max events in memory for the overlay.
  /// [localRetentionDays] -- how many days to keep events locally.
  Future<void> init({
    required String appFlavor,
    required String appVersion,
    required String platform,
    bool enableSync = true,
    Duration syncInterval = const Duration(minutes: 2),
    Set<String>? localOnlyEventTypes,
    int memoryLimit = 500,
    int localRetentionDays = 7,
  }) async {
    if (_initialized) return;

    _memoryLimit = memoryLimit;
    _localOnlyEventTypes = localOnlyEventTypes ?? {};

    _store = TrailifyStore();
    _identity = TrailifyIdentity();
    await _identity.init(
      appFlavor: appFlavor,
      appVersion: appVersion,
      platform: platform,
    );

    // Load recent events into memory for the overlay
    final recent = await _store.getRecent(limit: memoryLimit);
    entries.value = recent.map((r) => r.value).toList();

    // Clean up old events
    final cutoff = DateTime.now().subtract(Duration(days: localRetentionDays));
    await _store.deleteOlderThan(cutoff);

    // Start sync engine
    if (enableSync) {
      _syncEngine = TrailifySyncEngine(
        store: _store,
        syncInterval: syncInterval,
      );
      _syncEngine!.start();
    }

    _initialized = true;
  }

  /// Test-only initializer -- accepts pre-built dependencies, no platform plugins needed.
  ///
  /// Use with TrailifyStore.withFactory(databaseFactoryMemory, 'test.db')
  /// and TrailifyIdentity().initForTest(...) in scenario tests.
  /// This bypasses SharedPreferences, path_provider, and Firebase entirely.
  Future<void> initForTest({
    required TrailifyStore store,
    required TrailifyIdentity identity,
    TrailifySyncEngine? syncEngine,
    Set<String>? localOnlyEventTypes,
    int memoryLimit = 500,
  }) async {
    if (_initialized) return;

    _memoryLimit = memoryLimit;
    _localOnlyEventTypes = localOnlyEventTypes ?? {};
    _store = store;
    _identity = identity;
    _syncEngine = syncEngine;

    final recent = await _store.getRecent(limit: memoryLimit);
    entries.value = recent.map((r) => r.value).toList();

    _initialized = true;
  }

  /// Reset the singleton state. Test-only -- allows re-initialization between tests.
  void resetForTest() {
    _syncEngine?.stop();
    _initialized = false;
    entries.value = [];
  }

  // ── Identity ──

  void setUser({
    required String userId,
    required String email,
    required String appId,
  }) {
    _identity.setUser(
      userId: userId,
      email: email,
      appId: appId,
    );
    _identity.backfillUser(_store);
  }

  void clearUser() {
    _syncEngine?.flush();
    _identity.clearUser();
  }

  // ── Logging methods ──

  /// Core log method. All other methods delegate here.
  ///
  /// Determines syncStatus at creation time based on localOnlyEventTypes config.
  /// Events marked 'localOnly' are never picked up by the sync engine.
  Future<void> log({
    required String eventType,
    required Map<String, dynamic> payload,
  }) async {
    if (!_initialized) return;

    final syncStatus = _localOnlyEventTypes.contains(eventType)
        ? 'localOnly'
        : 'pending';

    final entry = {
      ..._identity.envelope(syncStatus: syncStatus),
      'eventType': eventType,
      'payload': payload,
    };

    // Write to in-memory list (for overlay)
    final current = List<Map<String, dynamic>>.from(entries.value);
    current.insert(0, entry);
    if (current.length > _memoryLimit) {
      current.removeRange(_memoryLimit, current.length);
    }
    entries.value = current;

    // Write to persistent store (fire-and-forget)
    _store.insert(entry);
  }

  // ── Convenience methods ──

  /// Log a notification event.
  void notification({
    required String eventType,
    String? messageId,
    String? title,
    String? body,
    String? topic,
    Map<String, dynamic>? data,
    String? source,
  }) {
    log(
      eventType: eventType,
      payload: {
        if (messageId != null) 'messageId': messageId,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (topic != null) 'topic': topic,
        if (data != null) 'data': data,
        if (source != null) 'source': source,
      },
    );
  }

  /// Log an auth event.
  void auth({
    required String eventType,
    Map<String, dynamic>? details,
  }) {
    log(eventType: eventType, payload: details ?? {});
  }

  /// Log an explicit user action.
  void userAction({
    required String action,
    Map<String, dynamic>? context,
  }) {
    log(
      eventType: 'user_action',
      payload: {
        'action': action,
        if (context != null) 'context': context,
      },
    );
  }

  /// Log a screen view.
  void screenView({
    required String screenName,
    Map<String, dynamic>? arguments,
  }) {
    log(
      eventType: 'screen_viewed',
      payload: {
        'screenName': screenName,
        if (arguments != null) 'arguments': arguments,
      },
    );
  }

  /// Log a caught error.
  void error({
    required Object error,
    StackTrace? stackTrace,
    String? context,
  }) {
    log(
      eventType: 'error',
      payload: {
        'error': error.toString(),
        if (stackTrace != null)
          'stackTrace': stackTrace.toString().length > 500
              ? '${stackTrace.toString().substring(0, 500)}...'
              : stackTrace.toString(),
        if (context != null) 'context': context,
      },
    );
  }

  // ── Debug overlay ──

  /// Open the debug console overlay.
  void openConsole(BuildContext context) { /* ... */ }

  // ── Lifecycle ──

  /// Flush pending syncs and close the database.
  Future<void> dispose() async {
    _syncEngine?.stop();
    await _syncEngine?.flush();
    await _store.close();
  }
}
```

## Firestore Data Model

### Collection: `event_logs`

Each document is an event with the envelope + payload structure defined above, minus the local-only `syncStatus` field, plus the Firestore-specific fields. The **document ID is the `eventId`** (UUID v4), making sync idempotent -- re-uploading the same event overwrites the same document instead of creating a duplicate.

```
{
  // Document ID = eventId (not stored as a field, it IS the doc ID)

  // Envelope fields (from the local entry)
  "deviceId": "a1b2c3d4-...",
  "userId": "USR_100042",
  "userEmail": "user@example.com",
  "appId": "app_one",
  "appFlavor": "prod",
  "eventType": "api_request",
  "timestamp": Timestamp,              // Firestore Timestamp (converted from ISO)
  "sessionId": "sess-uuid-...",
  "platform": "ios",
  "appVersion": "1.22.9",
  "firebaseProject": "my-project-dev-1",

  // Event-specific
  "payload": { ... },

  // Firestore-specific
  "expiresAt": Timestamp               // timestamp + 90 days, for TTL auto-delete
}
```

### Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Existing rules for remote_config
    match /remote_config/{document=**} {
      allow read: if true;
      allow write: if false;
    }

    // Event logs -- mobile clients can create, never read/update/delete.
    // Admin queries are done via Firebase Console or Admin SDK (bypasses rules).
    // App Check ensures only genuine app instances can write.
    match /event_logs/{logId} {
      allow create: if request.appCheck.token.size() > 0;
      allow read, update, delete: if false;
    }
  }
}
```

### Firebase App Check

The `event_logs` collection allows creates without Firebase Auth (to support pre-auth events like login failures). To prevent anyone with the project ID from writing garbage, **Firebase App Check is required**.

App Check verifies the request comes from a genuine app installation. Both apps already use Firebase, so this is a small addition:

1. **Firebase Console**: Enable App Check for Firestore. Choose DeviceCheck (iOS) and Play Integrity (Android) as attestation providers.
2. **Flutter**: Add `firebase_app_check` to your app's `pubspec.yaml`.
3. **Initialization**: Activate in `main()` before `Trailify.instance.init()`:

```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.deviceCheck,
);
```

4. **Enforcement**: In Firebase Console > App Check > APIs, enforce App Check for Cloud Firestore. Requests without a valid App Check token are rejected.

This prevents abuse while still allowing pre-auth writes from legitimate app installs.

### Composite Indexes

| Collection | Fields | Query Scope |
|---|---|---|
| `event_logs` | `userId` ASC, `timestamp` DESC | Collection |
| `event_logs` | `userEmail` ASC, `timestamp` DESC | Collection |
| `event_logs` | `userId` ASC, `eventType` ASC, `timestamp` DESC | Collection |
| `event_logs` | `deviceId` ASC, `timestamp` DESC | Collection |

### TTL Auto-Delete

Configure in Firebase Console > Firestore Database > Time-to-live:

- **Collection group**: `event_logs`
- **Timestamp field**: `expiresAt`

Documents are automatically deleted 90 days after the event occurred. No manual cleanup needed.

## Cloud Query Patterns

All queries are performed in **Firebase Console > Firestore Database** by team members, or via Admin SDK if a backend query tool is built later.

### "Show me everything user X did"

```
Collection: event_logs
Filter: userId == "USR_100042"
Order: timestamp DESC
```

This is the primary query. Returns a chronological trail of everything: screens visited, API calls made, notifications received, actions taken.

### "Did the user's message actually send?"

```
Collection: event_logs
Filter: userId == "USR_100042" AND eventType == "api_request"
Order: timestamp DESC
```

Look for the POST to `/api/v1/conversation/message`. Check `payload.statusCode` and `payload.responseBody`.

### "Did the user receive the notification?"

```
Collection: event_logs
Filter: userId == "USR_100042" AND eventType == "notification_received"
Order: timestamp DESC
```

### "What happened before the error?"

```
Collection: event_logs
Filter: userId == "USR_100042"
Order: timestamp DESC
Limit: 50
```

Read the events chronologically leading up to the error entry.

### "Show me pre-auth events for a device"

For cases where the user never successfully logged in:

```
Collection: event_logs
Filter: deviceId == "a1b2c3d4-..."
Order: timestamp DESC
```

### "What is this specific user doing across sessions?"

```
Collection: event_logs
Filter: userEmail == "user@example.com"
Order: timestamp DESC
```

Querying by email shows activity across all apps that share the same Firestore project.

## Debug Overlay

The debug overlay:

### Features

1. **Persistent**: On open, loads events from Sembast (not just in-memory). Events survive app restart.
2. **Unified tab**: Instead of separate tabs for Network/Navigation/Database/Notification, show a single chronological list with event type indicators (color-coded icons).
3. **Filter by event type**: Dropdown or chips to filter by `api_request`, `notification_received`, `user_action`, etc.
4. **Search**: Search across event payload content.
5. **Sync status indicator**: Show a small badge showing pending sync count.
6. **Event detail screen**: Tap any event to see full payload details (request body, response body, headers, etc.).

### Tab Structure

```
[All] [API] [Notifications] [Actions] [Auth] [Errors]
```

Each tab filters the same underlying list by `eventType`.

### Overlay Access

Password-protected floating button, long-press to open. Configured via:

```dart
Trailify.instance.openConsole(context);
```

## Privacy and Scrubbing

### What Gets Scrubbed (Before Local Storage)

The Dio interceptor scrubs before writing to Sembast:

| Field | Action |
|---|---|
| `Authorization` header | Replaced with `[REDACTED]` |
| `Cookie` / `Set-Cookie` headers | Replaced with `[REDACTED]` |
| `password` in request body | Replaced with `[REDACTED]` |
| `token` / `refreshToken` in request body | Replaced with `[REDACTED]` |
| `base64` in request body (file uploads) | Replaced with `[REDACTED]` |

### What Is NOT Stored

- Full file contents (images, PDFs) -- only the upload URL and file name
- Biometric data
- Full JWT tokens (only the first 20 chars of FCM tokens for device identification)

### Configurable Scrubbing

The interceptor accepts additional configuration:

```dart
TrailifyDioInterceptor(
  trailify,
  excludePatterns: [
    RegExp(r'/auth/token'),      // skip token endpoint entirely
    RegExp(r'/health'),          // skip health checks
  ],
  maxBodySize: 2000,             // truncate bodies larger than 2000 chars
  captureSuccessBodies: false,   // only capture bodies on errors (default)
  alwaysCaptureBodyPatterns: [
    RegExp(r'/conversation/message'),  // always capture for critical endpoints
  ],
);
```

## Integration Guide

### 1. Initialization

In your app's `main()` function, after Firebase initialization:

```dart
// Enable App Check first (before any Firestore writes)
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.deviceCheck,
);

await Trailify.instance.init(
  appFlavor: 'prod',
  appVersion: packageInfo.version,
  platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
  enableSync: true,
  syncInterval: const Duration(minutes: 2),
  localOnlyEventTypes: {'screen_viewed'},
);
```

### 2. User Identity

After login:

```dart
Trailify.instance.setUser(
  userId: user.id.toString(),
  email: user.email,
  appId: 'my_app',
);
```

On logout:

```dart
Trailify.instance.clearUser();
```

### 3. Dio Interceptor

Add to every Dio instance:

```dart
TrailifyDioInterceptor(
  Trailify.instance,
  alwaysCaptureBodyPatterns: [
    RegExp(r'/conversation/message'),
    RegExp(r'/notification'),
  ],
  excludePatterns: [
    RegExp(r'/health'),
  ],
)
```

### 4. Notification Events

In your Firebase messaging handler:

```dart
// _handleForegroundMessage
Trailify.instance.notification(
  eventType: 'notification_received',
  messageId: message.messageId,
  title: message.notification?.title,
  body: message.notification?.body,
  topic: message.from,
  data: message.data,
  source: 'foreground',
);

// firebaseMessagingBackgroundHandler
Trailify.instance.notification(
  eventType: 'notification_received',
  messageId: message.messageId,
  title: message.notification?.title,
  body: message.notification?.body,
  topic: message.from,
  data: message.data,
  source: 'background',
);

// _handleMessageOpenedApp
Trailify.instance.notification(
  eventType: 'notification_tapped',
  messageId: message.messageId,
  title: message.notification?.title,
  body: message.notification?.body,
  topic: message.from,
  data: message.data,
  source: 'background',
);

// handleInitialMessage (when initialMessage != null)
Trailify.instance.notification(
  eventType: 'notification_tapped',
  messageId: initialMessage.messageId,
  title: initialMessage.notification?.title,
  body: initialMessage.notification?.body,
  topic: initialMessage.from,
  data: initialMessage.data,
  source: 'terminated',
);

// _handleLocalNotificationTap
Trailify.instance.notification(
  eventType: 'notification_tapped',
  source: 'local',
);

// subscribe (after successful subscribeToTopic)
Trailify.instance.notification(
  eventType: 'notification_subscribed',
  topic: fullTopicName,
);

// unsubscribe loop
Trailify.instance.notification(
  eventType: 'notification_unsubscribed',
  topic: topic,
);
```

### 5. User Actions

Example: logging a message send:

```dart
// Before sending
Trailify.instance.userAction(
  action: 'send_message',
  details: {
    'conversationId': _conversationId,
    'textLength': htmlContent.length,
  },
);
```

Example: logging a file upload:

```dart
// Before upload
Trailify.instance.userAction(
  action: 'upload_images',
  details: {
    'conversationId': _conversationId,
    'imageCount': state.selectedImages.length,
  },
);
```

The actual API calls are auto-captured by the Dio interceptor. The `user_action` events provide the user-intent context that the raw API log doesn't have.

### 6. Auth Events

On login success:

```dart
Trailify.instance.auth(
  eventType: 'auth_login',
  details: { 'method': 'email_password', 'success': true },
);
```

On login failure:

```dart
Trailify.instance.auth(
  eventType: 'auth_login',
  details: { 'method': 'email_password', 'success': false, 'error': '...' },
);
```

On logout:

```dart
Trailify.instance.auth(
  eventType: 'auth_logout',
  details: { 'reason': 'user_initiated' },
);
```

On token refresh:

```dart
Trailify.instance.auth(
  eventType: 'auth_token_refresh',
  details: { 'success': true },
);
```

## Package Dependencies

### trailify package

```yaml
dependencies:
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

Sembast already includes `databaseFactoryMemory` in `package:sembast/sembast_memory.dart` -- no extra test package needed. `SharedPreferences` supports `SharedPreferences.setMockInitialValues({})` out of the box in Flutter test.

### Host app

Add `trailify` and `firebase_app_check` to your app's dependencies:

```yaml
dependencies:
  trailify:
    git:
      url: https://github.com/ChauCM/trailify.git
  firebase_app_check: ^0.3.3+2
```

## Cost Estimate

### Firestore Writes

- ~5,000 active parents
- Per user per day: ~5 notifications + ~50 API calls + ~10 user actions + ~5 auth events = ~70 events
- Total: 5,000 x 70 = 350,000 writes/day = ~10.5M writes/month
- Cost: 10.5M / 100K x $0.18 = **~$18.90/month**

### Reducing Cost If Needed

- Exclude `screen_viewed` events from sync (typically the highest volume, least useful remotely): reduces by ~30%
- Exclude successful GET requests (only sync POST/PUT/DELETE and all errors): reduces by ~50%
- Reduce sync to only errors + notifications + user actions: ~$3-5/month

### With Conservative Sync (recommended starting point)

Sync only: `api_error`, `notification_*`, `auth_*`, `user_action`, `error`

- Per user per day: ~5 notifications + ~5 errors + ~3 auth + ~10 user actions = ~23 events
- Total: 5,000 x 23 = 115,000 writes/day = ~3.5M writes/month
- Cost: **~$6.30/month**

### Firestore Storage

- Average document size: ~1 KB
- 3.5M docs/month with 90-day TTL = ~10.5M docs at steady state
- Storage: ~10.5 GB at $0.18/GB = **~$1.89/month**

### Firestore Reads (Admin Queries)

- Minimal. Looking up one user's events = 50-100 reads per investigation.
- Even with 10 investigations/day = 1,000 reads/day = well under free tier (50K/day).

### Total Estimated Cost

| Configuration | Monthly Cost |
|---|---|
| Sync everything | ~$20-22 |
| Conservative sync (errors + notifications + actions + auth) | ~$8-10 |
| Minimal sync (errors + notifications only) | ~$3-5 |

## Testability

### Design Principle

All core components accept injected dependencies so the full data pipeline can be exercised in `flutter test` without a device, emulator, or network. Production code uses the default constructors (which hardcode platform plugins). Test code uses the `*ForTest` constructors with in-memory replacements.

The testing approach is **scenario-based integration testing** -- not unit testing. Each test exercises a real user scenario through the actual data pipeline (event creation -> local storage -> sync to Firestore) using in-memory fakes that behave like the real databases.

### Why This Approach

- **Covers the big picture**: tests verify the full pipeline, not isolated methods
- **Replicates user-facing issues**: test scenarios map to real debugging scenarios ("message disappeared", "notification not received", "pre-auth events lost")
- **Easy for AI to run**: `flutter test` runs in seconds, clear pass/fail, no device needed
- **Real database behavior**: Sembast `databaseFactoryMemory` and `FakeFirebaseFirestore` implement the real APIs with real query/filter/sort behavior -- not hand-rolled mocks

### Testing Stack

| Dependency | Production | Test Replacement |
|---|---|---|
| Sembast (local DB) | `databaseFactoryIo` + `path_provider` | `databaseFactoryMemory` from `package:sembast/sembast_memory.dart` |
| Firestore (cloud sync) | `FirebaseFirestore.instance` | `FakeFirebaseFirestore()` from `package:fake_cloud_firestore` |
| SharedPreferences (device ID) | `SharedPreferences.getInstance()` | Bypassed via `TrailifyIdentity.initForTest()` |
| Firebase Core (project ID) | `Firebase.app().options.projectId` | Bypassed via `TrailifyIdentity.initForTest()` |

### Injection Points

**`TrailifyStore`**: Two constructors.

```dart
// Production (used by Trailify.init)
final store = TrailifyStore();

// Test (used by Trailify.initForTest)
final store = TrailifyStore.withFactory(databaseFactoryMemory, 'test.db');
```

**`TrailifyIdentity`**: Two init methods.

```dart
// Production
final identity = TrailifyIdentity();
await identity.init(appFlavor: 'prod', appVersion: '1.0.0', platform: 'ios');

// Test -- sets all fields directly, no SharedPreferences or Firebase
final identity = TrailifyIdentity();
identity.initForTest(deviceId: 'test-device-1', sessionId: 'test-session-1');
```

**`TrailifySyncEngine`**: Already accepts `FirebaseFirestore?` in constructor -- pass `FakeFirebaseFirestore()`.

```dart
final fakeFirestore = FakeFirebaseFirestore();
final syncEngine = TrailifySyncEngine(
  store: store,
  firestore: fakeFirestore,
  syncInterval: Duration.zero,  // disable timer in tests, call sync() directly
);
```

**`Trailify`**: Two init methods.

```dart
// Production
await Trailify.instance.init(appFlavor: 'prod', appVersion: '1.0.0', platform: 'ios');

// Test -- inject all dependencies, no platform plugins
await Trailify.instance.initForTest(
  store: store,
  identity: identity,
  syncEngine: syncEngine,  // optional, null to test without sync
  localOnlyEventTypes: {'screen_viewed'},
);

// Between tests
Trailify.instance.resetForTest();
```

### Scenario Test Structure

Tests live in `test/` at the package root. Each file covers a layer of the pipeline, building from bottom (store) to top (full integration).

```
test/
  trailify_store_test.dart           # local storage scenarios
  trailify_dio_interceptor_test.dart # HTTP capture + scrubbing scenarios
  trailify_sync_engine_test.dart     # Sembast -> Firestore sync scenarios
  trailify_integration_test.dart     # full pipeline end-to-end scenarios
```

**`trailify_store_test.dart`** -- exercises the local storage layer with a real in-memory Sembast database:
- Events persist across reads (insert, read back, verify structure and order)
- Pending events are queryable for sync (mix of pending/localOnly/synced, verify getPendingSync only returns pending)
- Retention policy deletes old events (insert events with old timestamps, run deleteOlderThan, verify count)
- Mark synced updates status (insert pending, mark synced, verify they leave getPendingSync)
- Pre-auth backfill updates userId (insert events with null userId, run backfillUserIdentity, verify userId set)

**`trailify_dio_interceptor_test.dart`** -- exercises the Dio interceptor by feeding it real Dio requests and verifying the events that come out:
- Successful GET produces api_request event with method, url, statusCode, durationMs
- Failed POST produces api_error event with error and errorType
- Sensitive headers are redacted (Authorization -> [REDACTED])
- Sensitive body fields are redacted (password -> [REDACTED])
- Excluded URL patterns produce no events
- Body capture respects captureSuccessBodies flag
- alwaysCaptureBodyPatterns overrides the default
- Large bodies are truncated at maxBodySize

**`trailify_sync_engine_test.dart`** -- exercises sync from Sembast to Firestore using FakeFirebaseFirestore:
- Pending events sync to Firestore (insert pending, run sync(), verify docs in FakeFirebaseFirestore)
- Synced events are marked locally (after sync, verify syncStatus: 'synced' in Sembast)
- Idempotent sync (sync same events twice, verify no duplicate docs -- eventId = doc ID)
- localOnly events never sync (insert localOnly, run sync, verify Firestore empty)
- syncStatus field is stripped from Firestore doc
- Timestamp is converted to Firestore Timestamp (not String)
- expiresAt = event time + 90 days

**`trailify_integration_test.dart`** -- end-to-end scenarios through the full Trailify class:
- Full audit trail for "message send" (init, set user, log userAction, simulate Dio POST, verify both events in store with correct userId, sync to Firestore, verify Firestore docs)
- Pre-auth events get backfilled (init, log events with no user, set user, verify old events now have userId)
- localOnly event types stay local (configure localOnlyEventTypes, log screen_viewed, sync, verify never in Firestore)
- clearUser flushes pending events (set user, log events, clearUser, verify sync attempted)
- In-memory list is capped at memoryLimit (log more than limit, verify entries.value.length does not exceed)

### Test Helper Pattern

Each test file uses the same setup pattern:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

late TrailifyStore store;
late TrailifyIdentity identity;
late FakeFirebaseFirestore fakeFirestore;

setUp(() async {
  // Fresh in-memory Sembast for each test
  store = TrailifyStore.withFactory(
    newDatabaseFactoryMemory(),
    'test.db',
  );

  // Identity with deterministic test values
  identity = TrailifyIdentity();
  identity.initForTest(
    deviceId: 'test-device-001',
    sessionId: 'test-session-001',
  );

  // Fresh in-memory Firestore for each test
  fakeFirestore = FakeFirebaseFirestore();

  // Reset the singleton between tests
  Trailify.instance.resetForTest();
});

tearDown(() async {
  await store.close();
});
```

## Summary: What Gets Built

### In the trailify package

1. `TrailifyStore` -- Sembast-based local document store
2. `TrailifyIdentity` -- user/device identity manager with backfill
3. `TrailifySyncEngine` -- batched Firestore sync with retry
4. `TrailifyDioInterceptor` -- Dio interceptor that captures request/response with scrubbing
5. `Trailify` class -- singleton with `init()`, `setUser()`, `clearUser()`, `log()`, and convenience methods
6. Debug overlay -- reads from Sembast, unified event list, filter by type

### In the host app

1. Enable Firebase App Check in `main()` (before Trailify init)
2. `Trailify.instance.init(...)` in `main()`
3. `setUser()` / `clearUser()` in auth flow
4. Add `TrailifyDioInterceptor` to Dio instances
5. Notification logging calls in your messaging handler
6. `userAction()` calls at key user actions
7. `auth()` calls in auth flow

### In Firebase Console

1. Enable App Check with DeviceCheck (iOS) and Play Integrity (Android)
2. Enforce App Check for Cloud Firestore
3. Security rules for `event_logs` collection (with App Check verification)
4. Composite indexes (4 indexes)
5. TTL policy on `expiresAt` field
