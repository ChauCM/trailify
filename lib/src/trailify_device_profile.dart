import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import 'trailify_store.dart';

class TrailifyDeviceProfile {
  final String deviceId;
  final String sessionId;
  final Map<String, dynamic> info;
  final String? appVersion;
  final String? appFlavor;

  static const _storeName = 'device_profile';
  static const _maxSessions = 20;

  TrailifyDeviceProfile({
    required this.deviceId,
    required this.sessionId,
    required this.info,
    this.appVersion,
    this.appFlavor,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      ...info,
      'appVersion': appVersion,
      'appFlavor': appFlavor,
      'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> save(TrailifyStore store) async {
    final database = await store.db;
    final profileStore = stringMapStoreFactory.store(_storeName);
    final record = profileStore.record(deviceId);

    final existing = await record.get(database);
    final sessions = <Map<String, dynamic>>[];

    if (existing != null) {
      final prev = existing['sessions'];
      if (prev is List) {
        sessions.addAll(prev.cast<Map<String, dynamic>>());
      }
    }

    sessions.add({
      'sessionId': sessionId,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      if (appVersion != null) 'appVersion': appVersion,
      if (info['osVersion'] != null) 'osVersion': info['osVersion'],
    });

    if (sessions.length > _maxSessions) {
      sessions.removeRange(0, sessions.length - _maxSessions);
    }

    final doc = {
      ...toMap(),
      'sessions': sessions,
    };

    await record.put(database, doc);
  }

  Future<void> syncToFirestore(FirebaseFirestore? firestore) async {
    if (firestore == null) return;

    try {
      final docRef = firestore.collection('device_profiles').doc(deviceId);
      final snapshot = await docRef.get();

      final sessions = <Map<String, dynamic>>[];
      if (snapshot.exists) {
        final prev = snapshot.data()?['sessions'];
        if (prev is List) {
          sessions.addAll(prev.cast<Map<String, dynamic>>());
        }
      }

      sessions.add({
        'sessionId': sessionId,
        'startedAt': Timestamp.now(),
        if (appVersion != null) 'appVersion': appVersion,
        if (info['osVersion'] != null) 'osVersion': info['osVersion'],
      });

      if (sessions.length > _maxSessions) {
        sessions.removeRange(0, sessions.length - _maxSessions);
      }

      await docRef.set({
        'deviceId': deviceId,
        ...info,
        'appVersion': appVersion,
        'appFlavor': appFlavor,
        'lastSeenAt': Timestamp.now(),
        'sessions': sessions,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TrailifyDeviceProfile: sync failed: $e');
    }
  }

  static Future<Map<String, dynamic>?> getLocal(
    TrailifyStore store,
    String deviceId,
  ) async {
    final database = await store.db;
    final profileStore = stringMapStoreFactory.store(_storeName);
    return profileStore.record(deviceId).get(database);
  }
}
