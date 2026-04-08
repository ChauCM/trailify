import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:trailify/src/trailify_store.dart';
import 'package:trailify/src/trailify_sync_engine.dart';

void main() {
  late TrailifyStore store;
  late FakeFirebaseFirestore fakeFirestore;
  late TrailifySyncEngine syncEngine;

  setUp(() async {
    store = TrailifyStore.withFactory(newDatabaseFactoryMemory(), 'test.db');
    fakeFirestore = FakeFirebaseFirestore();
    syncEngine = TrailifySyncEngine(
      store: store,
      firestore: fakeFirestore,
      syncInterval: const Duration(days: 999),
    );
  });

  tearDown(() async {
    syncEngine.stop();
    await store.close();
  });

  Map<String, dynamic> _makeEvent({
    required String eventId,
    String syncStatus = 'pending',
    DateTime? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now().toUtc();
    return {
      'eventId': eventId,
      'eventType': 'api_request',
      'timestamp': ts.toIso8601String(),
      'syncStatus': syncStatus,
      'deviceId': 'dev-1',
      'userId': 'USR_1',
      'payload': {'method': 'GET', 'url': '/test'},
    };
  }

  test('pending events sync to Firestore', () async {
    await store.insert(_makeEvent(eventId: 'evt-1'));
    await store.insert(_makeEvent(eventId: 'evt-2'));

    await syncEngine.sync();

    final docs = await fakeFirestore.collection('event_logs').get();
    expect(docs.docs, hasLength(2));
    final docIds = docs.docs.map((d) => d.id).toSet();
    expect(docIds, containsAll(['evt-1', 'evt-2']));
  });

  test('synced events are marked locally', () async {
    await store.insert(_makeEvent(eventId: 'evt-1'));

    await syncEngine.sync();

    final pending = await store.getPendingSync();
    expect(pending, isEmpty);

    final counts = await store.syncStatusCounts();
    expect(counts['synced'], 1);
    expect(counts['pending'], 0);
  });

  test('idempotent sync produces no duplicate docs', () async {
    await store.insert(_makeEvent(eventId: 'evt-1'));

    await syncEngine.sync();

    // Insert same eventId again as a new pending record
    await store.insert(_makeEvent(eventId: 'evt-1'));

    await syncEngine.sync();

    final docs = await fakeFirestore.collection('event_logs').get();
    expect(docs.docs, hasLength(1));
    expect(docs.docs.first.id, 'evt-1');
  });

  test('localOnly events never sync', () async {
    await store.insert(
      _makeEvent(eventId: 'evt-local', syncStatus: 'localOnly'),
    );

    await syncEngine.sync();

    final docs = await fakeFirestore.collection('event_logs').get();
    expect(docs.docs, isEmpty);
  });

  test('syncStatus field is stripped from Firestore doc', () async {
    await store.insert(_makeEvent(eventId: 'evt-1'));

    await syncEngine.sync();

    final doc =
        await fakeFirestore.collection('event_logs').doc('evt-1').get();
    expect(doc.data()!.containsKey('syncStatus'), isFalse);
  });

  test('timestamp is converted to Firestore Timestamp', () async {
    final eventTime = DateTime.utc(2026, 4, 15, 10, 30, 0);
    await store.insert(_makeEvent(eventId: 'evt-1', timestamp: eventTime));

    await syncEngine.sync();

    final doc =
        await fakeFirestore.collection('event_logs').doc('evt-1').get();
    final ts = doc.data()!['timestamp'];
    expect(ts, isA<Timestamp>());
    final storedMs = (ts as Timestamp).millisecondsSinceEpoch;
    expect(storedMs, eventTime.millisecondsSinceEpoch);
  });

  test('expiresAt is event time + 90 days', () async {
    final eventTime = DateTime.utc(2026, 4, 15, 10, 30, 0);
    await store.insert(_makeEvent(eventId: 'evt-1', timestamp: eventTime));

    await syncEngine.sync();

    final doc =
        await fakeFirestore.collection('event_logs').doc('evt-1').get();
    final expiresAt = doc.data()!['expiresAt'] as Timestamp;
    final expected = eventTime.add(const Duration(days: 90));
    expect(expiresAt.millisecondsSinceEpoch, expected.millisecondsSinceEpoch);
  });
}
