import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'trailify_store.dart';

class TrailifySyncEngine {
  final TrailifyStore _store;
  final FirebaseFirestore _firestore;
  final String _collection;

  Timer? _syncTimer;
  bool _isSyncing = false;

  final Duration _syncInterval;

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

  void start() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => sync());
    sync();
  }

  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final keys = <int>[];

    try {
      final pendingRecords = await _store.getPendingSync(limit: 500);
      if (pendingRecords.isEmpty) return;

      final batch = _firestore.batch();

      for (final record in pendingRecords) {
        final doc = Map<String, dynamic>.from(record.value);

        final eventId = doc['eventId'] as String?;
        if (eventId == null) continue;

        for (final field in _localOnlyFields) {
          doc.remove(field);
        }

        if (doc['timestamp'] is String) {
          doc['timestamp'] = Timestamp.fromDate(
            DateTime.parse(doc['timestamp'] as String),
          );
        }

        final eventTime = doc['timestamp'] is Timestamp
            ? (doc['timestamp'] as Timestamp).toDate()
            : DateTime.now();
        doc['expiresAt'] = Timestamp.fromDate(
          eventTime.add(const Duration(days: 90)),
        );

        final docRef = _firestore.collection(_collection).doc(eventId);
        batch.set(docRef, doc);
        keys.add(record.key);
      }

      await batch.commit();
      await _store.markSynced(keys);
    } catch (e) {
      debugPrint('TrailifySyncEngine: sync failed: $e');
      if (keys.isNotEmpty) {
        await _store.markFailed(keys);
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> flush() async {
    await sync();
  }
}
