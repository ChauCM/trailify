import 'package:flutter/widgets.dart';

import 'trailify.dart';

class TrailifyNavigatorObserver extends NavigatorObserver {
  final Trailify _trailify;

  TrailifyNavigatorObserver(this._trailify);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logScreenView(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _logScreenView(newRoute);
  }

  void _logScreenView(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    _trailify.screenView(
      screenName: name,
      arguments: route.settings.arguments is Map<String, dynamic>
          ? route.settings.arguments as Map<String, dynamic>
          : null,
    );
  }
}
