import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logarte/src/console/logarte_auth_screen.dart';
import 'package:logarte/src/console/logarte_overlay.dart';
import 'package:logarte/src/extensions/object_extensions.dart';
import 'package:logarte/src/extensions/route_extensions.dart';
import 'package:logarte/src/models/logarte_entry.dart';
import 'package:logarte/src/models/navigation_action.dart';
import 'package:logarte/src/persistence/logarte_persistence.dart';

class Logarte {
  final String? password;
  final bool ignorePassword;
  final Function(String data)? onShare;
  final int logBufferLength;
  final Function(BuildContext context)? onRocketLongPressed;
  final Function(BuildContext context)? onRocketDoubleTapped;
  final bool disableDebugConsoleLogs;
  final Widget? customTab;
  final bool disableAllLogs;
  final bool disableNavigationLogs;
  final bool disableDatabaseLogs;
  final bool disableNetworkLogs;
  final bool disablePlainLogs;
  final bool disableNotificationLogs;
  final bool showBackButton;
  final LogartePersistence? persistence;

  Logarte({
    this.password,
    this.ignorePassword = !kReleaseMode,
    this.onShare,
    this.onRocketLongPressed,
    this.onRocketDoubleTapped,
    this.logBufferLength = 2500,
    this.disableDebugConsoleLogs = false,
    this.customTab,
    this.disableAllLogs = false,
    this.disableNavigationLogs = false,
    this.disableDatabaseLogs = false,
    this.disableNetworkLogs = false,
    this.disablePlainLogs = false,
    this.disableNotificationLogs = false,
    this.showBackButton = true,
    this.persistence,
  });

  final logs = ValueNotifier(<LogarteEntry>[]);

  Future<void> init() async {
    if (persistence == null) return;
    await persistence!.init();
    final persisted = await persistence!.loadAll();
    if (persisted.isNotEmpty) {
      logs.value = [...persisted];
    }
  }

  void _add(LogarteEntry entry) {
    if (logs.value.length > logBufferLength) {
      logs.value.removeAt(0);
    }
    logs.value = [...logs.value, entry];

    persistence?.write(entry).catchError((_) {});
  }

  Future<void> clearLogs() async {
    logs.value = [];
    await persistence?.clear();
  }

  @Deprecated('Use logarte.log() instead')
  void info(
    Object? message, {
    bool write = true,
    String? source,
  }) {
    _log(
      message,
      write: write,
      source: source,
    );
  }

  void log(
    Object? message, {
    bool write = true,
    StackTrace? stackTrace,
    String? source,
  }) {
    _log(
      message,
      write: write,
      stackTrace: stackTrace,
      source: source,
    );
  }

  @Deprecated('Use logarte.log() instead')
  void error(
    Object? message, {
    StackTrace? stackTrace,
    bool write = true,
  }) {
    _log(
      'ERROR: $message\n\nTRACE: $stackTrace',
      write: write,
    );
  }

  void network({
    required NetworkRequestLogarteEntry request,
    required NetworkResponseLogarteEntry response,
    bool write = true,
  }) {
    try {
      _log(
        '[${request.method}] URL: ${request.url}',
        write: write,
      );
      _log(
        'HEADERS: ${request.headers.prettyJson}',
        write: write,
      );
      _log(
        'BODY: ${request.body.prettyJson}',
        write: write,
      );
      _log(
        'STATUS CODE: ${response.statusCode}',
        write: write,
      );
      _log(
        'RESPONSE HEADERS: ${response.headers.prettyJson}',
        write: write,
      );
      _log(
        'RESPONSE BODY: ${response.body.prettyJson}',
        write: write,
      );

      _add(
        NetworkLogarteEntry(
          request: request,
          response: response,
        ),
      );
    } catch (_) {}
  }

  void _log(
    Object? message, {
    bool write = true,
    String? source,
    StackTrace? stackTrace,
  }) {
    if (!disableDebugConsoleLogs) {
      developer.log(
        message.toString(),
        name: 'logarte',
        stackTrace: stackTrace,
      );
    }

    if (write) {
      _add(
        PlainLogarteEntry(
          '${message.toString()}${stackTrace != null ? '\n\n$stackTrace' : ''}',
          source: source,
        ),
      );
    }
  }

  void navigation({
    required Route<dynamic>? route,
    required Route<dynamic>? previousRoute,
    required NavigationAction action,
  }) {
    try {
      if ([route.routeName, previousRoute.routeName]
          .any((e) => e?.contains('/logarte') == true)) {
        return;
      }

      final rName = route?.settings.name;
      final pName = previousRoute?.settings.name;

      final message = previousRoute != null
          ? action == NavigationAction.pop
              ? '$action from "$rName" to "$pName"'
              : '$action to "$rName"'
          : '$action to "$rName"';

      _log(message, write: false);

      _add(
        NavigatorLogarteEntry(
          routeName: rName,
          routeArguments: route?.settings.arguments?.toString(),
          previousRouteName: pName,
          previousRouteArguments:
              previousRoute?.settings.arguments?.toString(),
          action: action,
        ),
      );
    } catch (_) {}
  }

  void database({
    required String target,
    required Object? value,
    required String source,
  }) {
    try {
      _log(
        '$source: $target → $value',
        write: false,
      );

      _add(
        DatabaseLogarteEntry(
          target: target,
          value: value,
          source: source,
        ),
      );
    } catch (_) {}
  }

  void notification({
    required NotificationEventType eventType,
    String? messageId,
    String? title,
    String? body,
    String? topic,
    Map<String, dynamic>? data,
    String? source,
  }) {
    try {
      _log(
        '[${eventType.name}] ${title ?? topic ?? eventType.name}',
        write: false,
      );

      _add(
        NotificationLogarteEntry(
          eventType: eventType,
          messageId: messageId,
          title: title,
          body: body,
          topic: topic,
          data: data,
          source: source,
        ),
      );
    } catch (_) {}
  }

  void attach({
    required BuildContext context,
    required bool visible,
  }) async {
    if (visible) {
      return LogarteOverlay.attach(
        context: context,
        instance: this,
      );
    }
  }

  Future<void> openConsole(BuildContext context) async {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LogarteAuthScreen(this),
        settings: const RouteSettings(name: '/logarte_auth'),
      ),
    );
  }
}
