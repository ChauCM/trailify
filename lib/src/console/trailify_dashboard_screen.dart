import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../trailify.dart';
import 'trailify_entry_item.dart';
import 'trailify_theme_wrapper.dart';

class TrailifyDashboardScreen extends StatefulWidget {
  const TrailifyDashboardScreen({Key? key}) : super(key: key);

  @override
  State<TrailifyDashboardScreen> createState() =>
      _TrailifyDashboardScreenState();
}

class _TrailifyDashboardScreenState extends State<TrailifyDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final TabController _tabController;

  bool _showFilters = false;
  _FilterState _filters = const _FilterState();

  static const _tabs = <_TabDef>[
    _TabDef('All', Icons.list_alt_rounded, null),
    _TabDef('API', Icons.public, _apiFilter),
    _TabDef('Navigation', Icons.navigation_rounded, _navigationFilter),
    _TabDef('Notifications', Icons.notifications_rounded, _notificationFilter),
    _TabDef('Actions', Icons.touch_app_rounded, _actionFilter),
    _TabDef('Auth', Icons.lock_rounded, _authFilter),
    _TabDef('Errors', Icons.error_rounded, _errorFilter),
  ];

  static bool _apiFilter(String t) => t == 'api_request' || t == 'api_error';
  static bool _navigationFilter(String t) => t == 'screen_viewed';
  static bool _notificationFilter(String t) => t.startsWith('notification_');
  static bool _actionFilter(String t) => t == 'user_action';
  static bool _authFilter(String t) => t.startsWith('auth_');
  static bool _errorFilter(String t) => t == 'error';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> entries,
    bool Function(String)? typeFilter,
    String search,
  ) {
    var filtered = entries;

    if (typeFilter != null) {
      filtered = filtered.where((e) {
        final t = e['eventType'] as String? ?? '';
        return typeFilter(t);
      }).toList();
    }

    if (_filters.timeRange != null) {
      final cutoff =
          DateTime.now().subtract(_filters.timeRange!).toUtc().toIso8601String();
      filtered = filtered.where((e) {
        final ts = e['timestamp'] as String? ?? '';
        return ts.compareTo(cutoff) >= 0;
      }).toList();
    }

    if (_filters.syncStatuses.isNotEmpty) {
      filtered = filtered.where((e) {
        final s = e['syncStatus'] as String? ?? '';
        return _filters.syncStatuses.contains(s);
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

    if (search.isNotEmpty) {
      filtered = filtered.where((e) {
        return e.toString().toLowerCase().contains(search);
      }).toList();
    }

    return filtered;
  }

  Map<int, int> _countPerTab(List<Map<String, dynamic>> allEntries) {
    final counts = <int, int>{};
    for (var i = 0; i < _tabs.length; i++) {
      final tab = _tabs[i];
      if (tab.typeFilter == null) {
        counts[i] = allEntries.length;
      } else {
        counts[i] = allEntries
            .where((e) => tab.typeFilter!(e['eventType'] as String? ?? ''))
            .length;
      }
    }
    return counts;
  }

  void _shareFilteredEvents(List<Map<String, dynamic>> entries) {
    final tabIndex = _tabController.index;
    final search = _searchController.text.toLowerCase();
    final filtered = _applyFilters(entries, _tabs[tabIndex].typeFilter, search);

    final text = const JsonEncoder.withIndent('  ').convert(filtered);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${filtered.length} events copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TrailifyThemeWrapper(
      child: Scaffold(
        body: ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: Trailify.instance.entries,
          builder: (context, allEntries, _) {
            final counts = _countPerTab(allEntries);

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    pinned: true,
                    leading: const BackButton(),
                    title: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search events...',
                        filled: true,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        ),
                      ),
                    ),
                    actions: [
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(_showFilters
                                ? Icons.filter_list_off
                                : Icons.filter_list),
                            onPressed: () =>
                                setState(() => _showFilters = !_showFilters),
                            tooltip: 'Filters',
                          ),
                          if (_filters.activeCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${_filters.activeCount}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10),
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded),
                        onPressed: () => _shareFilteredEvents(allEntries),
                        tooltip: 'Export filtered events',
                      ),
                    ],
                    bottom: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      labelPadding:
                          const EdgeInsets.symmetric(horizontal: 10.0),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: List.generate(_tabs.length, (i) {
                        final tab = _tabs[i];
                        final count = counts[i] ?? 0;
                        return Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tab.icon, size: 18),
                              const SizedBox(width: 4),
                              Text(tab.label),
                              if (count > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  if (_showFilters)
                    SliverToBoxAdapter(
                      child: _FilterBar(
                        filters: _filters,
                        currentTabIndex: _tabController.index,
                        onChanged: (f) => setState(() => _filters = f),
                      ),
                    ),
                ];
              },
              body: AnimatedBuilder(
                animation: _searchController,
                builder: (_, __) {
                  final search = _searchController.text.toLowerCase();
                  return TabBarView(
                    controller: _tabController,
                    children: List.generate(_tabs.length, (i) {
                      final tab = _tabs[i];
                      final filtered =
                          _applyFilters(allEntries, tab.typeFilter, search);
                      return _EventListWithSections(
                        entries: filtered,
                        showStats: i == 0,
                        allEntries: allEntries,
                      );
                    }),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Filter state ──

class _FilterState {
  final Duration? timeRange;
  final Set<String> syncStatuses;
  final Set<String> httpStatusRanges;

  const _FilterState({
    this.timeRange,
    this.syncStatuses = const {},
    this.httpStatusRanges = const {},
  });

  int get activeCount =>
      (timeRange != null ? 1 : 0) +
      (syncStatuses.isNotEmpty ? 1 : 0) +
      (httpStatusRanges.isNotEmpty ? 1 : 0);

  _FilterState copyWith({
    Duration? Function()? timeRange,
    Set<String>? syncStatuses,
    Set<String>? httpStatusRanges,
  }) {
    return _FilterState(
      timeRange: timeRange != null ? timeRange() : this.timeRange,
      syncStatuses: syncStatuses ?? this.syncStatuses,
      httpStatusRanges: httpStatusRanges ?? this.httpStatusRanges,
    );
  }
}

// ── Filter bar ──

class _FilterBar extends StatelessWidget {
  final _FilterState filters;
  final int currentTabIndex;
  final ValueChanged<_FilterState> onChanged;

  const _FilterBar({
    required this.filters,
    required this.currentTabIndex,
    required this.onChanged,
  });

  static const _timePresets = <String, Duration?>{
    'All time': null,
    '5 min': Duration(minutes: 5),
    '15 min': Duration(minutes: 15),
    '1 hour': Duration(hours: 1),
    '24 hours': Duration(hours: 24),
  };

  static const _syncOptions = ['pending', 'synced', 'failed', 'localOnly'];
  static const _httpRanges = ['2xx', '3xx', '4xx', '5xx'];

  @override
  Widget build(BuildContext context) {
    final isApiTab = currentTabIndex == 1;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              const Text('Time',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const Spacer(),
              if (filters.activeCount > 0)
                TextButton(
                  onPressed: () => onChanged(const _FilterState()),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear all', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _timePresets.entries.map((entry) {
              final isSelected = filters.timeRange == entry.value;
              return ChoiceChip(
                label: Text(entry.key),
                selected: isSelected,
                onSelected: (_) => onChanged(
                  filters.copyWith(timeRange: () => entry.value),
                ),
                labelStyle: const TextStyle(fontSize: 11),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.sync, size: 14, color: Colors.grey),
              SizedBox(width: 6),
              Text('Sync status',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _syncOptions.map((status) {
              final isSelected = filters.syncStatuses.contains(status);
              return FilterChip(
                label: Text(status),
                selected: isSelected,
                onSelected: (selected) {
                  final updated = Set<String>.from(filters.syncStatuses);
                  selected ? updated.add(status) : updated.remove(status);
                  onChanged(filters.copyWith(syncStatuses: updated));
                },
                labelStyle: const TextStyle(fontSize: 11),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          if (isApiTab) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.http, size: 14, color: Colors.grey),
                SizedBox(width: 6),
                Text('HTTP status',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _httpRanges.map((range) {
                final isSelected = filters.httpStatusRanges.contains(range);
                return FilterChip(
                  label: Text(range),
                  selected: isSelected,
                  onSelected: (selected) {
                    final updated =
                        Set<String>.from(filters.httpStatusRanges);
                    selected ? updated.add(range) : updated.remove(range);
                    onChanged(filters.copyWith(httpStatusRanges: updated));
                  },
                  labelStyle: const TextStyle(fontSize: 11),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stats header ──

class _StatsHeader extends StatelessWidget {
  final List<Map<String, dynamic>> allEntries;

  const _StatsHeader({required this.allEntries});

  @override
  Widget build(BuildContext context) {
    var pending = 0;
    var synced = 0;
    var failed = 0;
    var errors = 0;

    for (final e in allEntries) {
      final status = e['syncStatus'] as String? ?? '';
      if (status == 'pending') pending++;
      if (status == 'synced') synced++;
      if (status == 'failed') failed++;
      if (e['eventType'] == 'error') errors++;
    }

    String timeRange = '';
    if (allEntries.isNotEmpty) {
      final newest = allEntries.first['timestamp'] as String? ?? '';
      final oldest = allEntries.last['timestamp'] as String? ?? '';
      if (newest.isNotEmpty && oldest.isNotEmpty) {
        try {
          final n = DateTime.parse(newest).toLocal();
          final o = DateTime.parse(oldest).toLocal();
          timeRange = '${_shortDate(o)} — ${_shortDate(n)}';
        } catch (_) {}
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _StatChip('Total', '${allEntries.length}', Colors.blueGrey),
          const SizedBox(width: 8),
          _StatChip('Pending', '$pending', Colors.orange),
          const SizedBox(width: 8),
          _StatChip('Synced', '$synced', Colors.green),
          const SizedBox(width: 8),
          _StatChip('Failed', '$failed', Colors.deepOrange),
          const SizedBox(width: 8),
          _StatChip('Errors', '$errors', Colors.red),
          if (timeRange.isNotEmpty) ...[
            const Spacer(),
            Text(timeRange,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  static String _shortDate(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}

// ── Tab definition ──

class _TabDef {
  final String label;
  final IconData icon;
  final bool Function(String eventType)? typeFilter;

  const _TabDef(this.label, this.icon, this.typeFilter);
}

// ── Event list with date separators and stats ──

class _EventListWithSections extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final bool showStats;
  final List<Map<String, dynamic>> allEntries;

  const _EventListWithSections({
    required this.entries,
    required this.showStats,
    required this.allEntries,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('No events', style: TextStyle(color: Colors.grey)),
      );
    }

    final items = _buildItemsWithSeparators(entries);

    return Scrollbar(
      child: CustomScrollView(
        slivers: [
          if (showStats)
            SliverToBoxAdapter(child: _StatsHeader(allEntries: allEntries)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                if (item is _DateSeparator) {
                  return _DateSeparatorWidget(label: item.label);
                }
                return Column(
                  children: [
                    TrailifyEntryItem(event: item as Map<String, dynamic>),
                    const Divider(height: 0),
                  ],
                );
              },
              childCount: items.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  List<Object> _buildItemsWithSeparators(List<Map<String, dynamic>> entries) {
    final items = <Object>[];
    String? lastLabel;

    for (final entry in entries) {
      final label = _dateLabelForEntry(entry);
      if (label != lastLabel) {
        items.add(_DateSeparator(label));
        lastLabel = label;
      }
      items.add(entry);
    }

    return items;
  }

  static String _dateLabelForEntry(Map<String, dynamic> entry) {
    final ts = entry['localTimestamp'] as String? ?? entry['timestamp'] as String?;
    if (ts == null || ts.isEmpty) return 'Unknown';

    try {
      final dt = entry.containsKey('localTimestamp')
          ? DateTime.parse(ts)
          : DateTime.parse(ts).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eventDay = DateTime(dt.year, dt.month, dt.day);

      if (eventDay == today) return 'Today';
      if (eventDay == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      }

      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final diff = today.difference(eventDay).inDays;
      if (diff < 7) return weekdays[dt.weekday - 1];

      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return 'Unknown';
    }
  }
}

class _DateSeparator {
  final String label;
  const _DateSeparator(this.label);
}

class _DateSeparatorWidget extends StatelessWidget {
  final String label;
  const _DateSeparatorWidget({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
