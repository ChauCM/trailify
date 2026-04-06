import 'package:flutter/material.dart';

import 'trailify_identity.dart';
import 'trailify_store.dart';
import 'trailify_sync_engine.dart';

class Trailify {
  static final Trailify instance = Trailify._();
  Trailify._();

  late TrailifyStore _store;
  late TrailifyIdentity _identity;
  TrailifySyncEngine? _syncEngine;

  final ValueNotifier<List<Map<String, dynamic>>> entries =
      ValueNotifier([]);

  int _memoryLimit = 500;

  Set<String> _localOnlyEventTypes = {};

  bool _initialized = false;

  String? _password;
  bool _ignorePassword = true;
  Function(String data)? _onShare;

  String? get password => _password;
  bool get ignorePassword => _ignorePassword;
  Function(String data)? get onShare => _onShare;
  TrailifyStore get store => _store;

  Future<void> init({
    required String appFlavor,
    required String appVersion,
    required String platform,
    bool enableSync = true,
    Duration syncInterval = const Duration(minutes: 2),
    Set<String>? localOnlyEventTypes,
    int memoryLimit = 500,
    int localRetentionDays = 7,
    String? password,
    bool ignorePassword = true,
    Function(String data)? onShare,
  }) async {
    if (_initialized) return;

    _memoryLimit = memoryLimit;
    _localOnlyEventTypes = localOnlyEventTypes ?? {};
    _password = password;
    _ignorePassword = ignorePassword;
    _onShare = onShare;

    _store = TrailifyStore();
    _identity = TrailifyIdentity();
    await _identity.init(
      appFlavor: appFlavor,
      appVersion: appVersion,
      platform: platform,
    );

    final recent = await _store.getRecent(limit: memoryLimit);
    entries.value = recent.map((r) => r.value).toList();

    final cutoff = DateTime.now().subtract(Duration(days: localRetentionDays));
    await _store.deleteOlderThan(cutoff);

    if (enableSync) {
      _syncEngine = TrailifySyncEngine(
        store: _store,
        syncInterval: syncInterval,
      );
      _syncEngine!.start();
    }

    _initialized = true;
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

    final current = List<Map<String, dynamic>>.from(entries.value);
    current.insert(0, entry);
    if (current.length > _memoryLimit) {
      current.removeRange(_memoryLimit, current.length);
    }
    entries.value = current;

    // Fire-and-forget -- logging must never block the app.
    _store.insert(entry);
  }

  // ── Convenience methods ──

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

  void auth({
    required String eventType,
    Map<String, dynamic>? details,
  }) {
    log(eventType: eventType, payload: details ?? {});
  }

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

  // ── Testing ──

  Future<void> initForTest({
    required TrailifyStore store,
    required TrailifyIdentity identity,
    TrailifySyncEngine? syncEngine,
    Set<String>? localOnlyEventTypes,
    int memoryLimit = 500,
  }) async {
    if (_initialized) return;

    _store = store;
    _identity = identity;
    _syncEngine = syncEngine;
    _memoryLimit = memoryLimit;
    _localOnlyEventTypes = localOnlyEventTypes ?? {};

    final recent = await _store.getRecent(limit: memoryLimit);
    entries.value = recent.map((r) => r.value).toList();

    _initialized = true;
  }

  void resetForTest() {
    _syncEngine?.stop();
    _syncEngine = null;
    _initialized = false;
    entries.value = [];
    _localOnlyEventTypes = {};
    _memoryLimit = 500;
  }

  // ── Debug overlay ──

  void openConsole(BuildContext context) {
    // Will be wired in Phase 5.
  }

  // ── Lifecycle ──

  Future<void> dispose() async {
    _syncEngine?.stop();
    await _syncEngine?.flush();
    await _store.close();
  }
}
