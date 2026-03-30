import 'package:sembast/sembast_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TrailifyStore {
  static const _dbName = 'trailify_audit.db';
  static const _storeName = 'events';

  Database? _db;
  final _store = intMapStoreFactory.store(_storeName);

  Future<Database> get db async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);
    return databaseFactoryIo.openDatabase(dbPath);
  }

  Future<int> insert(Map<String, dynamic> entry) async {
    final database = await db;
    return _store.add(database, entry);
  }

  Future<List<RecordSnapshot<int, Map<String, dynamic>>>> getRecent({
    int limit = 200,
    String? eventTypeFilter,
  }) async {
    final database = await db;
    final finder = Finder(
      sortOrders: [SortOrder('timestamp', false)],
      limit: limit,
    );
    if (eventTypeFilter != null) {
      finder.filter = Filter.equals('eventType', eventTypeFilter);
    }
    return _store.find(database, finder: finder);
  }

  Future<List<RecordSnapshot<int, Map<String, dynamic>>>> getPendingSync({
    int limit = 500,
  }) async {
    final database = await db;
    return _store.find(
      database,
      finder: Finder(
        filter: Filter.equals('syncStatus', 'pending'),
        sortOrders: [SortOrder('timestamp', true)],
        limit: limit,
      ),
    );
  }

  Future<void> markSynced(List<int> keys) async {
    final database = await db;
    await database.transaction((txn) async {
      for (final key in keys) {
        await _store.record(key).update(txn, {'syncStatus': 'synced'});
      }
    });
  }

  Future<void> markFailed(List<int> keys) async {
    final database = await db;
    await database.transaction((txn) async {
      for (final key in keys) {
        await _store.record(key).update(txn, {'syncStatus': 'failed'});
      }
    });
  }

  Future<int> deleteOlderThan(DateTime cutoff) async {
    final database = await db;
    final filter = Filter.lessThan('timestamp', cutoff.toIso8601String());
    return _store.delete(database, finder: Finder(filter: filter));
  }

  Future<Map<String, int>> syncStatusCounts() async {
    final database = await db;
    final pending = await _store.count(
      database,
      filter: Filter.equals('syncStatus', 'pending'),
    );
    final synced = await _store.count(
      database,
      filter: Filter.equals('syncStatus', 'synced'),
    );
    final failed = await _store.count(
      database,
      filter: Filter.equals('syncStatus', 'failed'),
    );
    return {'pending': pending, 'synced': synced, 'failed': failed};
  }

  Future<int> count() async {
    final database = await db;
    return _store.count(database);
  }

  /// Find pre-auth events from the current session that have no userId.
  Future<List<RecordSnapshot<int, Map<String, dynamic>>>> findPreAuthEvents(
    String sessionId,
  ) async {
    final database = await db;
    return _store.find(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('sessionId', sessionId),
          Filter.isNull('userId'),
        ]),
      ),
    );
  }

  /// Backfill user identity onto pre-auth events.
  Future<void> backfillUserIdentity({
    required List<RecordSnapshot<int, Map<String, dynamic>>> records,
    required String userId,
    String? userEmail,
    String? appId,
  }) async {
    if (records.isEmpty) return;
    final database = await db;
    await database.transaction((txn) async {
      for (final record in records) {
        await _store.record(record.key).update(txn, {
          'userId': userId,
          'userEmail': userEmail,
          'appId': appId,
        });
      }
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
