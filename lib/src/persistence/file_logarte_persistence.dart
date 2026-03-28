import 'dart:convert';
import 'dart:io';

import 'package:logarte/src/models/logarte_entry.dart';
import 'package:logarte/src/persistence/logarte_persistence.dart';

class FileLogartePersistence extends LogartePersistence {
  final Directory directory;
  final Duration maxAge;
  final int maxEntries;

  late final File _file;

  FileLogartePersistence({
    required this.directory,
    this.maxAge = const Duration(days: 7),
    this.maxEntries = 2500,
  });

  @override
  Future<void> init() async {
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    _file = File('${directory.path}/logarte_logs.jsonl');
  }

  @override
  Future<void> write(LogarteEntry entry) async {
    try {
      final line = jsonEncode(entry.toJson());
      await _file.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  @override
  Future<List<LogarteEntry>> loadAll() async {
    try {
      if (!_file.existsSync()) return [];

      final content = await _file.readAsString();
      if (content.trim().isEmpty) return [];

      final cutoff = DateTime.now().subtract(maxAge);
      final entries = <LogarteEntry>[];

      for (final line in content.split('\n')) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final entry = LogarteEntry.fromJson(json);
          if (entry.date.isAfter(cutoff)) {
            entries.add(entry);
          }
        } catch (_) {
          // Skip corrupted lines
        }
      }

      // Keep only the newest maxEntries
      if (entries.length > maxEntries) {
        entries.removeRange(0, entries.length - maxEntries);
      }

      // Rewrite the pruned file
      await _rewrite(entries);

      return entries;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> clear() async {
    try {
      if (_file.existsSync()) {
        await _file.delete();
      }
    } catch (_) {}
  }

  Future<void> _rewrite(List<LogarteEntry> entries) async {
    try {
      final buffer = StringBuffer();
      for (final entry in entries) {
        buffer.writeln(jsonEncode(entry.toJson()));
      }
      await _file.writeAsString(buffer.toString(), flush: true);
    } catch (_) {}
  }
}
