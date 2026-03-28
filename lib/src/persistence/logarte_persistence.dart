import 'package:logarte/src/models/logarte_entry.dart';

abstract class LogartePersistence {
  Future<void> init();
  Future<void> write(LogarteEntry entry);
  Future<List<LogarteEntry>> loadAll();
  Future<void> clear();
}
