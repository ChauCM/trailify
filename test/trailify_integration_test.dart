import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:trailify/src/trailify.dart';
import 'package:trailify/src/trailify_identity.dart';
import 'package:trailify/src/trailify_store.dart';
import 'package:trailify/src/trailify_sync_engine.dart';

void main() {
  late TrailifyStore store;
  late TrailifyIdentity identity;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() async {
    store = TrailifyStore.withFactory(newDatabaseFactoryMemory(), 'test.db');
    identity = TrailifyIdentity();
    identity.initForTest(
      deviceId: 'test-device-001',
      sessionId: 'test-session-001',
    );
    fakeFirestore = FakeFirebaseFirestore();
    Trailify.instance.resetForTest();
  });

  tearDown(() async {
    Trailify.instance.resetForTest();
    // Don't close store in tearDown -- fire-and-forget inserts may still be in-flight
  });

  test('full audit trail: log -> store -> sync -> Firestore', () async {
    final syncEngine = TrailifySyncEngine(
      store: store,
      firestore: fakeFirestore,
      syncInterval: const Duration(days: 999),
    );

    await Trailify.instance.initForTest(
      store: store,
      identity: identity,
      syncEngine: syncEngine,
    );

    Trailify.instance.setUser(
      userId: 'USR_100042',
      email: 'user@example.com',
      appId: 'app_one',
    );

    Trailify.instance.userAction(
      action: 'send_message',
      details: {'conversationId': 42, 'textLength': 156},
    );

    await Trailify.instance.log(
      eventType: 'api_request',
      payload: {
        'method': 'POST',
        'url': '/api/v1/conversation/message',
        'statusCode': 200,
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(Trailify.instance.entries.value, hasLength(2));

    final stored = await store.getRecent(limit: 10);
    expect(stored, hasLength(2));

    await syncEngine.sync();

    final docs = await fakeFirestore.collection('event_logs').get();
    expect(docs.docs, hasLength(2));

    final eventTypes = docs.docs.map((d) => d.data()['eventType']).toSet();
    expect(eventTypes, containsAll(['user_action', 'api_request']));

    for (final doc in docs.docs) {
      expect(doc.data()['userId'], 'USR_100042');
    }
  });

  test('pre-auth events get backfilled on setUser', () async {
    await Trailify.instance.initForTest(
      store: store,
      identity: identity,
    );

    await Trailify.instance.log(
      eventType: 'auth_login',
      payload: {'method': 'keycloak', 'success': false, 'error': 'timeout'},
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    var stored = await store.getRecent(limit: 10);
    expect(stored.first.value['userId'], isNull);

    Trailify.instance.setUser(
      userId: 'USR_100042',
      email: 'user@example.com',
      appId: 'app_one',
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    stored = await store.getRecent(limit: 10);
    expect(stored.first.value['userId'], 'USR_100042');
    expect(stored.first.value['userEmail'], 'user@example.com');
  });

  test('localOnly event types stay local after sync', () async {
    final syncEngine = TrailifySyncEngine(
      store: store,
      firestore: fakeFirestore,
      syncInterval: const Duration(days: 999),
    );

    await Trailify.instance.initForTest(
      store: store,
      identity: identity,
      syncEngine: syncEngine,
      localOnlyEventTypes: {'screen_viewed'},
    );

    Trailify.instance.screenView(screenName: 'HomePage');
    await Trailify.instance.log(
      eventType: 'api_request',
      payload: {'method': 'GET', 'url': '/api/v1/feed'},
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await syncEngine.sync();

    final docs = await fakeFirestore.collection('event_logs').get();
    expect(docs.docs, hasLength(1));
    expect(docs.docs.first.data()['eventType'], 'api_request');
  });

  test('clearUser flushes pending events', () async {
    final syncEngine = TrailifySyncEngine(
      store: store,
      firestore: fakeFirestore,
      syncInterval: const Duration(days: 999),
    );

    await Trailify.instance.initForTest(
      store: store,
      identity: identity,
      syncEngine: syncEngine,
    );

    Trailify.instance.setUser(
      userId: 'USR_100042',
      email: 'user@example.com',
      appId: 'app_one',
    );

    await Trailify.instance.log(
      eventType: 'user_action',
      payload: {'action': 'some_action'},
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    Trailify.instance.clearUser();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final docs = await fakeFirestore.collection('event_logs').get();
    expect(docs.docs, hasLength(1));
  });

  test('in-memory list is capped at memoryLimit', () async {
    await Trailify.instance.initForTest(
      store: store,
      identity: identity,
      memoryLimit: 5,
    );

    for (var i = 0; i < 10; i++) {
      await Trailify.instance.log(
        eventType: 'user_action',
        payload: {'action': 'action_$i'},
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(Trailify.instance.entries.value.length, 5);

    final firstPayload =
        Trailify.instance.entries.value.first['payload'] as Map;
    expect(firstPayload['action'], 'action_9');
  });
}
