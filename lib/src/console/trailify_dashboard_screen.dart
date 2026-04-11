import 'package:flutter/material.dart';
import '../trailify.dart';
import 'trailify_entry_item.dart';
import 'trailify_theme_wrapper.dart';

class TrailifyDashboardScreen extends StatefulWidget {
  const TrailifyDashboardScreen({Key? key}) : super(key: key);

  @override
  State<TrailifyDashboardScreen> createState() =>
      _TrailifyDashboardScreenState();
}

class _TrailifyDashboardScreenState extends State<TrailifyDashboardScreen> {
  late final TextEditingController _searchController;

  static const _tabs = <_TabDef>[
    _TabDef('All', Icons.list_alt_rounded, null),
    _TabDef('API', Icons.public, _apiFilter),
    _TabDef('Notifications', Icons.notifications_rounded, _notificationFilter),
    _TabDef('Actions', Icons.touch_app_rounded, _actionFilter),
    _TabDef('Auth', Icons.lock_rounded, _authFilter),
    _TabDef('Errors', Icons.error_rounded, _errorFilter),
  ];

  static bool _apiFilter(String t) =>
      t == 'api_request' || t == 'api_error';
  static bool _notificationFilter(String t) => t.startsWith('notification_');
  static bool _actionFilter(String t) =>
      t == 'user_action' || t == 'screen_viewed';
  static bool _authFilter(String t) => t.startsWith('auth_');
  static bool _errorFilter(String t) => t == 'error';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TrailifyThemeWrapper(
      child: DefaultTabController(
        length: _tabs.length,
        child: Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  leading: const BackButton(),
                  title: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      filled: true,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                    ),
                  ),
                  bottom: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    labelPadding:
                        const EdgeInsets.symmetric(horizontal: 12.0),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: _tabs
                        .map((t) => Tab(icon: Icon(t.icon), text: t.label))
                        .toList(),
                  ),
                ),
              ];
            },
            body: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: Trailify.instance.entries,
              builder: (context, allEntries, _) {
                return AnimatedBuilder(
                  animation: _searchController,
                  builder: (_, __) {
                    final search = _searchController.text.toLowerCase();
                    return TabBarView(
                      children: _tabs.map((tab) {
                        return _EventList(
                          entries: allEntries,
                          typeFilter: tab.typeFilter,
                          search: search,
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  final bool Function(String eventType)? typeFilter;

  const _TabDef(this.label, this.icon, this.typeFilter);
}

class _EventList extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final bool Function(String)? typeFilter;
  final String search;

  const _EventList({
    Key? key,
    required this.entries,
    required this.typeFilter,
    required this.search,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var filtered = entries;

    if (typeFilter != null) {
      filtered = filtered.where((e) {
        final t = e['eventType'] as String? ?? '';
        return typeFilter!(t);
      }).toList();
    }

    if (search.isNotEmpty) {
      filtered = filtered.where((e) {
        return e.toString().toLowerCase().contains(search);
      }).toList();
    }

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No events', style: TextStyle(color: Colors.grey)),
      );
    }

    return Scrollbar(
      child: ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: filtered.length,
        padding: const EdgeInsets.only(bottom: 32.0, top: 8.0),
        itemBuilder: (context, index) {
          return TrailifyEntryItem(event: filtered[index]);
        },
        separatorBuilder: (_, __) => const Divider(height: 0.0),
      ),
    );
  }
}
