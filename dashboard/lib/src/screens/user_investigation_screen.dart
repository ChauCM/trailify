import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_query_service.dart';
import '../widgets/event_detail_panel.dart';
import '../widgets/event_entry_item.dart';
import '../widgets/filter_bar.dart';

class UserInvestigationScreen extends StatefulWidget {
  final String? initialQuery;
  const UserInvestigationScreen({super.key, this.initialQuery});

  @override
  State<UserInvestigationScreen> createState() => _UserInvestigationScreenState();
}

class _UserInvestigationScreenState extends State<UserInvestigationScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _service = FirestoreQueryService();
  late final TabController _tabController;

  List<Map<String, dynamic>> _events = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;
  String? _activeQuery;
  String? _activeField;
  FilterState _filters = const FilterState();
  bool _showFilters = false;
  Map<String, dynamic>? _selectedEvent;

  static const _tabs = <_TabDef>[
    _TabDef('All', Icons.list_alt_rounded, null),
    _TabDef('API', Icons.public, ['api_request', 'api_error']),
    _TabDef('Notifications', Icons.notifications_rounded, [
      'notification_received', 'notification_tapped',
      'notification_subscribed', 'notification_unsubscribed',
    ]),
    _TabDef('Actions', Icons.touch_app_rounded, ['user_action']),
    _TabDef('Auth', Icons.lock_rounded, ['auth_login', 'auth_logout', 'auth_token_refresh']),
    _TabDef('Errors', Icons.error_rounded, ['error', 'api_error']),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _doSearch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() { _loading = true; _error = null; _events = []; _lastDoc = null; _hasMore = false; _selectedEvent = null; });

    final field = FirestoreQueryService.detectField(query);
    _activeQuery = query;
    _activeField = field;

    try {
      final page = await _service.queryEvents(EventQuery(field: field, value: query));
      setState(() {
        _events = page.events;
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_activeQuery == null || _activeField == null || !_hasMore || _loading) return;
    setState(() => _loading = true);

    try {
      final page = await _service.queryEvents(
        EventQuery(field: _activeField!, value: _activeQuery!),
        startAfter: _lastDoc,
      );
      setState(() {
        _events.addAll(page.events);
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> _filteredEvents(List<String>? typeFilter) {
    var filtered = _events;

    if (typeFilter != null) {
      filtered = filtered.where((e) {
        final t = e['eventType'] as String? ?? '';
        return typeFilter.contains(t);
      }).toList();
    }

    if (_filters.timeRange != null) {
      final cutoff = DateTime.now().subtract(_filters.timeRange!).toUtc().toIso8601String();
      filtered = filtered.where((e) {
        final ts = e['timestamp'] as String? ?? '';
        return ts.compareTo(cutoff) >= 0;
      }).toList();
    }

    if (_filters.httpStatusRanges.isNotEmpty) {
      filtered = filtered.where((e) {
        final payload = e['payload'] as Map<String, dynamic>? ?? {};
        final statusCode = payload['statusCode'];
        if (statusCode == null) return true;
        final code = statusCode is int ? statusCode : int.tryParse('$statusCode') ?? 0;
        final range = '${code ~/ 100}xx';
        return _filters.httpStatusRanges.contains(range);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Column(
      children: [
        _buildSearchBar(),
        if (_showFilters)
          FilterBar(
            filters: _filters,
            showHttpFilter: _tabController.index == 1,
            onChanged: (f) => setState(() => _filters = f),
          ),
        Expanded(
          child: _events.isEmpty && !_loading
              ? _buildEmptyState()
              : isWide
                  ? _buildWideLayout()
                  : _buildNarrowLayout(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by userId, email, or deviceId...',
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); setState(() {}); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (_) => _doSearch(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _loading ? null : _doSearch, child: const Text('Search')),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'Filters',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Search for a user to investigate', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 4),
          Text('Enter a userId, email, or deviceId above', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildEventList()),
        if (_selectedEvent != null)
          Container(width: 1, color: Theme.of(context).dividerColor),
        if (_selectedEvent != null)
          Expanded(
            flex: 2,
            child: EventDetailPanel(
              event: _selectedEvent!,
              onClose: () => setState(() => _selectedEvent = null),
              onSessionTap: _selectedEvent!['sessionId'] != null && _selectedEvent!['userId'] != null
                  ? () => _navigateToSession(_selectedEvent!['userId'], _selectedEvent!['sessionId'])
                  : null,
              onDeviceTap: _selectedEvent!['deviceId'] != null
                  ? () => _navigateToDevice(_selectedEvent!['deviceId'])
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return _buildEventList();
  }

  Widget _buildEventList() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: (_) => setState(() {}),
          tabs: _tabs.map((t) {
            final count = _filteredEvents(t.types).length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon, size: 16),
                  const SizedBox(width: 4),
                  Text(t.label),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
        Expanded(
          child: Builder(builder: (context) {
            final tab = _tabs[_tabController.index];
            final filtered = _filteredEvents(tab.types);

            if (_loading && filtered.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (filtered.isEmpty) {
              return const Center(child: Text('No events', style: TextStyle(color: Colors.grey)));
            }

            return ListView.separated(
              itemCount: filtered.length + (_hasMore ? 1 : 0),
              separatorBuilder: (context2, index2) => const Divider(height: 0),
              itemBuilder: (context, index) {
                if (index == filtered.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _loading
                          ? const CircularProgressIndicator()
                          : OutlinedButton(onPressed: _loadMore, child: const Text('Load more')),
                    ),
                  );
                }
                final event = filtered[index];
                final isSelected = _selectedEvent?['eventId'] == event['eventId'];
                return Container(
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withAlpha(50) : null,
                  child: EventEntryItem(
                    event: event,
                    onTap: () {
                      final isWide = MediaQuery.of(context).size.width > 900;
                      if (isWide) {
                        setState(() => _selectedEvent = event);
                      } else {
                        _showDetailSheet(context, event);
                      }
                    },
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  void _showDetailSheet(BuildContext context, Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: EventDetailPanel(
          event: event,
          onClose: () => Navigator.of(context).pop(),
          onSessionTap: event['sessionId'] != null && event['userId'] != null
              ? () {
                  Navigator.of(context).pop();
                  _navigateToSession(event['userId'], event['sessionId']);
                }
              : null,
          onDeviceTap: event['deviceId'] != null
              ? () {
                  Navigator.of(context).pop();
                  _navigateToDevice(event['deviceId']);
                }
              : null,
        ),
      ),
    );
  }

  void _navigateToSession(String userId, String sessionId) {
    Navigator.of(context).pushNamed('/session', arguments: {'userId': userId, 'sessionId': sessionId});
  }

  void _navigateToDevice(String deviceId) {
    Navigator.of(context).pushNamed('/device', arguments: {'deviceId': deviceId});
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  final List<String>? types;
  const _TabDef(this.label, this.icon, this.types);
}
