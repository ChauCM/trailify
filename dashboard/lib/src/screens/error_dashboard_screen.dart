import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_query_service.dart';
import '../widgets/event_detail_panel.dart';
import '../widgets/event_entry_item.dart';

class ErrorDashboardScreen extends StatefulWidget {
  const ErrorDashboardScreen({super.key});

  @override
  State<ErrorDashboardScreen> createState() => _ErrorDashboardScreenState();
}

class _ErrorDashboardScreenState extends State<ErrorDashboardScreen> {
  final _service = FirestoreQueryService();

  List<Map<String, dynamic>> _errors = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = false;
  bool _loading = true;
  String? _error;
  Duration _timeRange = const Duration(hours: 24);
  Map<String, dynamic>? _selectedEvent;

  static const _timePresets = {
    '1h': Duration(hours: 1),
    '24h': Duration(hours: 24),
    '7d': Duration(days: 7),
    '30d': Duration(days: 30),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _errors = []; _lastDoc = null; });

    try {
      final since = DateTime.now().subtract(_timeRange);
      final page = await _service.queryErrors(since: since);
      setState(() {
        _errors = page.events;
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    setState(() => _loading = true);

    try {
      final since = DateTime.now().subtract(_timeRange);
      final page = await _service.queryErrors(startAfter: _lastDoc, since: since);
      setState(() {
        _errors.addAll(page.events);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupErrors() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final event in _errors) {
      final payload = event['payload'] as Map<String, dynamic>? ?? {};
      final eventType = event['eventType'] as String? ?? '';

      String key;
      if (eventType == 'api_error') {
        final method = payload['method'] ?? '';
        final url = payload['url'] ?? '';
        final status = payload['statusCode'] ?? '?';
        key = '[$method] $url -> $status';
      } else {
        final err = payload['error'] as String? ?? 'Unknown error';
        key = err.length > 80 ? '${err.substring(0, 80)}...' : err;
      }
      groups.putIfAbsent(key, () => []).add(event);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: isWide
              ? Row(
                  children: [
                    Expanded(flex: 3, child: _buildContent()),
                    if (_selectedEvent != null) Container(width: 1, color: Theme.of(context).dividerColor),
                    if (_selectedEvent != null)
                      Expanded(
                        flex: 2,
                        child: EventDetailPanel(
                          event: _selectedEvent!,
                          onClose: () => setState(() => _selectedEvent = null),
                        ),
                      ),
                  ],
                )
              : _buildContent(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Text('${_errors.length} errors', style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          ..._timePresets.entries.map((entry) {
            final selected = _timeRange == entry.value;
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ChoiceChip(
                label: Text(entry.key),
                selected: selected,
                onSelected: (_) {
                  _timeRange = entry.value;
                  _load();
                },
                labelStyle: const TextStyle(fontSize: 11),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading && _errors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_errors.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green[200]),
            const SizedBox(height: 12),
            Text('No errors in this time range', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    final groups = _groupErrors();
    final sortedKeys = groups.keys.toList()..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));

    return ListView.builder(
      itemCount: sortedKeys.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == sortedKeys.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : OutlinedButton(onPressed: _loadMore, child: const Text('Load more')),
            ),
          );
        }

        final key = sortedKeys[index];
        final events = groups[key]!;
        final firstEvent = events.first;
        final eventType = firstEvent['eventType'] as String? ?? '';

        return ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('${events.length}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red, fontSize: 13)),
          ),
          title: Text(key, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '$eventType | Last: ${EventEntryItem.formatTimestamp(firstEvent)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          children: events.take(5).map((event) {
            return EventEntryItem(
              event: event,
              onTap: () {
                if (MediaQuery.of(context).size.width > 900) {
                  setState(() => _selectedEvent = event);
                } else {
                  _showDetail(event);
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showDetail(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: EventDetailPanel(event: event, onClose: () => Navigator.of(context).pop()),
      ),
    );
  }
}
