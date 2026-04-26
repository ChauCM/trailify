import 'dart:convert';
import 'package:web/web.dart' as web;

import 'package:firebase_core/firebase_core.dart';

const _storageKey = 'trailify_firebase_config';

class FirebaseConfigProvider {
  static Map<String, dynamic>? getSavedConfig() {
    final raw = web.window.localStorage.getItem(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = json.decode(raw) as Map<String, dynamic>;
      if (_isValid(parsed)) return parsed;
    } catch (_) {}
    return null;
  }

  static void saveConfig(Map<String, dynamic> config) {
    web.window.localStorage.setItem(_storageKey, json.encode(config));
  }

  static void clearConfig() {
    web.window.localStorage.removeItem(_storageKey);
  }

  static bool _isValid(Map<String, dynamic> config) {
    return config['apiKey'] != null &&
        config['projectId'] != null &&
        config['authDomain'] != null;
  }

  static FirebaseOptions toFirebaseOptions(Map<String, dynamic> config) {
    return FirebaseOptions(
      apiKey: config['apiKey'] as String,
      appId: config['appId'] as String? ?? '',
      messagingSenderId: config['messagingSenderId'] as String? ?? '',
      projectId: config['projectId'] as String,
      authDomain: config['authDomain'] as String?,
      storageBucket: config['storageBucket'] as String?,
    );
  }

  static Map<String, dynamic>? parseConfigInput(String input) {
    try {
      final trimmed = input.trim();

      if (trimmed.startsWith('{')) {
        final parsed = json.decode(trimmed) as Map<String, dynamic>;
        if (_isValid(parsed)) return parsed;
      }

      final fields = <String, String>{};
      final regex = RegExp(r'(\w+)\s*[:=]\s*["\x27]([^"\x27]+)["\x27]');
      for (final match in regex.allMatches(trimmed)) {
        fields[match.group(1)!] = match.group(2)!;
      }
      if (fields['apiKey'] != null && fields['projectId'] != null) {
        return fields;
      }
    } catch (_) {}
    return null;
  }
}
