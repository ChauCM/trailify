import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'trailify_store.dart';

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

  String? get sessionId => _sessionId;

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

  void setUser({
    required String userId,
    required String email,
    required String appId,
  }) {
    _userId = userId;
    _userEmail = email;
    _appId = appId;
  }

  void clearUser() {
    _userId = null;
    _userEmail = null;
    _appId = null;
  }

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

  Future<void> backfillUser(TrailifyStore store) async {
    if (_userId == null || _sessionId == null) return;

    final preAuthEvents = await store.findPreAuthEvents(_sessionId!);

    await store.backfillUserIdentity(
      records: preAuthEvents,
      userId: _userId!,
      userEmail: _userEmail,
      appId: _appId,
    );
  }

  void initForTest({
    String deviceId = 'test-device',
    String sessionId = 'test-session',
    String appFlavor = 'test',
    String appVersion = '1.0.0',
    String platform = 'ios',
  }) {
    _deviceId = deviceId;
    _sessionId = sessionId;
    _appFlavor = appFlavor;
    _appVersion = appVersion;
    _platform = platform;
  }

  String _generateUuid() {
    return const Uuid().v4();
  }
}
