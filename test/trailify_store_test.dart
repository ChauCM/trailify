import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:trailify/src/trailify_store.dart';

void main() {
  late TrailifyStore store;

  setUp(() async {
    store = TrailifyStore.withFactory(newDatabaseFactoryMemory(), 'test.db');
  });

  tearDown(() async {
    await store.close();
  });

  test('events persist across reads', () async {
    final event = {
      'eventId': 'evt-1',
      'eventType': 'user_action',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'syncStatus': 'pending',
      'payload': {'action': 'tap_button'},
    };

    await store.insert(event);
    final results = await store.getRecent(limit: 10);

    expect(results, hasLength(1));
    expect(results.first.value['eventId'], 'evt-1');
    expect(results.first.value['eventType'], 'user_action');
    expect(results.first.value['payload']['action'], 'tap_button');
  });

  test('getPendingSync only returns pending events', () async {
    final now = DateTime.now().toUtc();
    await store.insert({
      'eventId': 'evt-pending',
      'eventType': 'api_request',
      'timestamp': now.toIso8601String(),
      'syncStatus': 'pending',
    });
    await store.insert({
      'eventId': 'evt-local',
      'eventType': 'screen_viewed',
      'timestamp': now.add(const Duration(seconds: 1)).toIso8601String(),
      'syncStatus': 'localOnly',
    });
    await store.insert({
      'eventId': 'evt-synced',
      'eventType': 'api_request',
      'timestamp': now.add(const Duration(seconds: 2)).toIso8601String(),
      'syncStatus': 'synced',
    });

    final pending = await store.getPendingSync();
    expect(pending, hasLength(1));
    expect(pending.first.value['eventId'], 'evt-pending');
  });

  test('retention policy deletes old events', () async {
    final old = DateTime.now().subtract(const Duration(days: 10)).toUtc();
    final recent = DateTime.now().toUtc();

    await store.insert({
      'eventId': 'evt-old',
      'timestamp': old.toIso8601String(),
      'syncStatus': 'synced',
    });
    await store.insert({
      'eventId': 'evt-recent',
      'timestamp': recent.toIso8601String(),
      'syncStatus': 'pending',
    });

    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final deleted = await store.deleteOlderThan(cutoff);

    expect(deleted, 1);
    final remaining = await store.getRecent(limit: 100);
    expect(remaining, hasLength(1));
    expect(remaining.first.value['eventId'], 'evt-recent');
  });

  test('markSynced updates status', () async {
    await store.insert({
      'eventId': 'evt-1',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'syncStatus': 'pending',
    });

    final pending = await store.getPendingSync();
    expect(pending, hasLength(1));

    await store.markSynced([pending.first.key]);

    final stillPending = await store.getPendingSync();
    expect(stillPending, isEmpty);

    final counts = await store.syncStatusCounts();
    expect(counts['synced'], 1);
    expect(counts['pending'], 0);
  });

  test('pre-auth backfill updates userId on matching events', () async {
    const sessionId = 'sess-abc';
    await store.insert({
      'eventId': 'evt-pre-1',
      'sessionId': sessionId,
      'userId': null,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'syncStatus': 'pending',
    });
    await store.insert({
      'eventId': 'evt-pre-2',
      'sessionId': 'other-session',
      'userId': null,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'syncStatus': 'pending',
    });

    final preAuth = await store.findPreAuthEvents(sessionId);
    expect(preAuth, hasLength(1));

    await store.backfillUserIdentity(
      records: preAuth,
      userId: 'USR_123',
      userEmail: 'user@test.com',
      appId: 'test_app',
    );

    final all = await store.getRecent(limit: 100);
    final backfilled = all.firstWhere(
      (r) => r.value['eventId'] == 'evt-pre-1',
    );
    expect(backfilled.value['userId'], 'USR_123');
    expect(backfilled.value['userEmail'], 'user@test.com');

    final untouched = all.firstWhere(
      (r) => r.value['eventId'] == 'evt-pre-2',
    );
    expect(untouched.value['userId'], isNull);
  });
}
