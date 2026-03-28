import 'package:flutter/material.dart';
import 'package:logarte/logarte.dart';
import 'package:logarte/src/console/logarte_entry_item.dart';
import 'package:logarte/src/console/logarte_theme_wrapper.dart';

class LogarteDashboardScreen extends StatefulWidget {
  final Logarte instance;

  const LogarteDashboardScreen(
    this.instance, {
    Key? key,
  }) : super(key: key);

  @override
  State<LogarteDashboardScreen> createState() => _LogarteDashboardScreenState();
}

class _LogarteDashboardScreenState extends State<LogarteDashboardScreen> {
  late final TextEditingController _controller;
  late int tabLength;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    tabLength = widget.instance.customTab != null ? 7 : 6;
    if (widget.instance.disableAllLogs) {
      tabLength--;
    }
    if (widget.instance.disablePlainLogs) {
      tabLength--;
    }
    if (widget.instance.disableNetworkLogs) {
      tabLength--;
    }
    if (widget.instance.disableDatabaseLogs) {
      tabLength--;
    }
    if (widget.instance.disableNavigationLogs) {
      tabLength--;
    }
    if (widget.instance.disableNotificationLogs) {
      tabLength--;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LogarteThemeWrapper(
      child: DefaultTabController(
        length: tabLength,
        child: Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  leading: widget.instance.showBackButton
                      ? BackButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        )
                      : null,
                  automaticallyImplyLeading: false,
                  title: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      filled: true,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _controller.clear,
                      ),
                    ),
                  ),
                  bottom: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12.0),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      if (!widget.instance.disableAllLogs)
                        Tab(
                          icon: const Icon(Icons.list_alt_rounded),
                          text: 'All (${widget.instance.logs.value.length})',
                        ),
                      if (!widget.instance.disablePlainLogs)
                        Tab(
                          icon: const Icon(Icons.bug_report_rounded),
                          text:
                              'Logging (${widget.instance.logs.value.whereType<PlainLogarteEntry>().length})',
                        ),
                      if (!widget.instance.disableNetworkLogs)
                        Tab(
                          icon: const Icon(Icons.public),
                          text:
                              'Network (${widget.instance.logs.value.whereType<NetworkLogarteEntry>().length})',
                        ),
                      if (!widget.instance.disableDatabaseLogs)
                        Tab(
                          icon: const Icon(Icons.save_as_rounded),
                          text:
                              'Database (${widget.instance.logs.value.whereType<DatabaseLogarteEntry>().length})',
                        ),
                      if (!widget.instance.disableNavigationLogs)
                        Tab(
                          icon: const Icon(Icons.navigation_rounded),
                          text:
                              'Navigation (${widget.instance.logs.value.whereType<NavigatorLogarteEntry>().length})',
                        ),
                      if (!widget.instance.disableNotificationLogs)
                        Tab(
                          icon: const Icon(Icons.notifications_rounded),
                          text:
                              'Notifications (${widget.instance.logs.value.whereType<NotificationLogarteEntry>().length})',
                        ),
                      if (widget.instance.customTab != null)
                        const Tab(
                          icon: Icon(Icons.extension_rounded),
                          text: 'Custom',
                        ),
                    ],
                  ),
                ),
              ];
            },
            // To rebuild the list when the logs list gets modified
            body: ValueListenableBuilder(
              valueListenable: widget.instance.logs,
              builder: (context, values, child) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    final search = _controller.text.toLowerCase();

                    return TabBarView(
                      children: [
                        if (!widget.instance.disableAllLogs)
                          _List<LogarteEntry>(
                            instance: widget.instance,
                            search: search,
                          ),
                        if (!widget.instance.disablePlainLogs)
                          _List<PlainLogarteEntry>(
                            instance: widget.instance,
                            search: search,
                          ),
                        if (!widget.instance.disableNetworkLogs)
                          _List<NetworkLogarteEntry>(
                            instance: widget.instance,
                            search: search,
                          ),
                        if (!widget.instance.disableDatabaseLogs)
                          _List<DatabaseLogarteEntry>(
                            instance: widget.instance,
                            search: search,
                          ),
                        if (!widget.instance.disableNavigationLogs)
                          _List<NavigatorLogarteEntry>(
                            instance: widget.instance,
                            search: search,
                          ),
                        if (!widget.instance.disableNotificationLogs)
                          _List<NotificationLogarteEntry>(
                            instance: widget.instance,
                            search: search,
                          ),
                        if (widget.instance.customTab != null)
                          widget.instance.customTab!,
                      ],
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

class _List<T extends LogarteEntry> extends StatelessWidget {
  const _List({Key? key, required this.instance, required this.search})
      : super(key: key);

  final Logarte instance;
  final String search;

  @override
  Widget build(BuildContext context) {
    final logs = T == LogarteEntry
        ? instance.logs.value
        : instance.logs.value.whereType<T>().toList();

    final filtered = logs.where((log) {
      return log.contents.any(
        (content) => content.toLowerCase().contains(search),
      );
    }).toList();

    return Scrollbar(
      child: ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: filtered.length,
        padding: const EdgeInsets.only(bottom: 32.0, top: 8.0),
        itemBuilder: (context, index) {
          final log = filtered.reversed.toList()[index];

          return LogarteEntryItem(log, instance: instance);
        },
        separatorBuilder: (context, index) => const Divider(height: 0.0),
      ),
    );
  }
}
