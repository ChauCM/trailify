import 'package:cloud_firestore/cloud_firestore.dart';

class EventQuery {
  final String field;
  final String value;
  final String? eventTypeFilter;
  final DateTime? startDate;
  final DateTime? endDate;

  const EventQuery({
    required this.field,
    required this.value,
    this.eventTypeFilter,
    this.startDate,
    this.endDate,
  });
}

class EventPage {
  final List<Map<String, dynamic>> events;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  const EventPage({required this.events, this.lastDoc, this.hasMore = false});
}

class FirestoreQueryService {
  final FirebaseFirestore _firestore;
  static const _collection = 'event_logs';
  static const _deviceProfilesCollection = 'device_profiles';
  static const _pageSize = 50;

  FirestoreQueryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static String detectField(String input) {
    if (input.contains('@')) return 'userEmail';
    if (input.startsWith('USR_') || RegExp(r'^\d+$').hasMatch(input)) return 'userId';
    if (input.length > 20 && input.contains('-')) return 'deviceId';
    return 'userId';
  }

  Future<EventPage> queryEvents(
    EventQuery query, {
    DocumentSnapshot? startAfter,
    int pageSize = _pageSize,
  }) async {
    Query q = _firestore
        .collection(_collection)
        .where(query.field, isEqualTo: query.value)
        .orderBy('timestamp', descending: true);

    if (query.eventTypeFilter != null) {
      q = _firestore
          .collection(_collection)
          .where(query.field, isEqualTo: query.value)
          .where('eventType', isEqualTo: query.eventTypeFilter)
          .orderBy('timestamp', descending: true);
    }

    if (query.startDate != null) {
      q = q.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(query.startDate!));
    }
    if (query.endDate != null) {
      q = q.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(query.endDate!));
    }

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    q = q.limit(pageSize + 1);

    final snapshot = await q.get();
    final docs = snapshot.docs;
    final hasMore = docs.length > pageSize;
    final pageDocs = hasMore ? docs.sublist(0, pageSize) : docs;

    return EventPage(
      events: pageDocs.map((d) => _docToEvent(d)).toList(),
      lastDoc: pageDocs.isNotEmpty ? pageDocs.last : null,
      hasMore: hasMore,
    );
  }

  Future<List<Map<String, dynamic>>> querySessionEvents({
    required String userId,
    required String sessionId,
  }) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('timestamp', descending: false)
        .limit(500)
        .get();

    return snapshot.docs.map((d) => _docToEvent(d)).toList();
  }

  Future<Map<String, dynamic>?> getDeviceProfile(String deviceId) async {
    final doc = await _firestore
        .collection(_deviceProfilesCollection)
        .doc(deviceId)
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<EventPage> queryErrors({
    DocumentSnapshot? startAfter,
    DateTime? since,
    int pageSize = _pageSize,
  }) async {
    Query q = _firestore
        .collection(_collection)
        .where('eventType', whereIn: ['error', 'api_error'])
        .orderBy('timestamp', descending: true);

    if (since != null) {
      q = q.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    }
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    q = q.limit(pageSize + 1);

    final snapshot = await q.get();
    final docs = snapshot.docs;
    final hasMore = docs.length > pageSize;
    final pageDocs = hasMore ? docs.sublist(0, pageSize) : docs;

    return EventPage(
      events: pageDocs.map((d) => _docToEvent(d)).toList(),
      lastDoc: pageDocs.isNotEmpty ? pageDocs.last : null,
      hasMore: hasMore,
    );
  }

  Map<String, dynamic> _docToEvent(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['timestamp'];
    if (ts is Timestamp) {
      data['timestamp'] = ts.toDate().toUtc().toIso8601String();
    }
    final expiresAt = data['expiresAt'];
    if (expiresAt is Timestamp) {
      data['expiresAt'] = expiresAt.toDate().toUtc().toIso8601String();
    }
    data['_docId'] = doc.id;
    data['_docRef'] = doc;
    return data;
  }
}
