import 'dart:convert';

import 'package:logarte/src/extensions/object_extensions.dart';
import 'package:logarte/src/models/logarte_type.dart';
import 'package:logarte/src/models/navigation_action.dart';

abstract class LogarteEntry {
  final LogarteType type;
  final DateTime _date;

  LogarteEntry(this.type, {DateTime? date}) : _date = date ?? DateTime.now();

  DateTime get date => _date;
  String get timeFormatted =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second}';

  List<String> get contents;

  Map<String, dynamic> toJson();

  static LogarteEntry fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'plain':
        return PlainLogarteEntry.fromJson(json);
      case 'network':
        return NetworkLogarteEntry.fromJson(json);
      case 'database':
        return DatabaseLogarteEntry.fromJson(json);
      case 'navigation':
        return NavigatorLogarteEntry.fromJson(json);
      case 'notification':
        return NotificationLogarteEntry.fromJson(json);
      default:
        throw ArgumentError('Unknown LogarteEntry type: $type');
    }
  }
}

class PlainLogarteEntry extends LogarteEntry {
  final String message;
  final String? source;

  PlainLogarteEntry(
    this.message, {
    this.source,
    DateTime? date,
  }) : super(LogarteType.plain, date: date);

  PlainLogarteEntry.fromJson(Map<String, dynamic> json)
      : message = json['message'] as String,
        source = json['source'] as String?,
        super(
          LogarteType.plain,
          date: DateTime.parse(json['date'] as String),
        );

  @override
  List<String> get contents => [
        message,
        if (source != null) source!,
      ];

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'date': date.toIso8601String(),
        'message': message,
        if (source != null) 'source': source,
      };
}

class NavigatorLogarteEntry extends LogarteEntry {
  final String? routeName;
  final String? routeArguments;
  final String? previousRouteName;
  final String? previousRouteArguments;
  final NavigationAction action;

  NavigatorLogarteEntry({
    required this.routeName,
    required this.routeArguments,
    required this.previousRouteName,
    required this.previousRouteArguments,
    required this.action,
    DateTime? date,
  }) : super(LogarteType.navigation, date: date);

  NavigatorLogarteEntry.fromJson(Map<String, dynamic> json)
      : routeName = json['routeName'] as String?,
        routeArguments = json['routeArguments'] as String?,
        previousRouteName = json['previousRouteName'] as String?,
        previousRouteArguments = json['previousRouteArguments'] as String?,
        action = NavigationAction.values.byName(json['action'] as String),
        super(
          LogarteType.navigation,
          date: DateTime.parse(json['date'] as String),
        );

  @override
  List<String> get contents => [
        if (routeName != null) routeName!,
        if (routeArguments != null) routeArguments!,
        action.name,
        if (previousRouteName != null) previousRouteName!,
        if (previousRouteArguments != null) previousRouteArguments!,
      ];

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'date': date.toIso8601String(),
        if (routeName != null) 'routeName': routeName,
        if (routeArguments != null) 'routeArguments': routeArguments,
        if (previousRouteName != null) 'previousRouteName': previousRouteName,
        if (previousRouteArguments != null)
          'previousRouteArguments': previousRouteArguments,
        'action': action.name,
      };
}

class DatabaseLogarteEntry extends LogarteEntry {
  final String target;
  final Object? value;
  final String source;

  DatabaseLogarteEntry({
    required this.target,
    required this.value,
    required this.source,
    DateTime? date,
  }) : super(LogarteType.database, date: date);

  DatabaseLogarteEntry.fromJson(Map<String, dynamic> json)
      : target = json['target'] as String,
        value = _decodeObject(json['value']),
        source = json['source'] as String,
        super(
          LogarteType.database,
          date: DateTime.parse(json['date'] as String),
        );

  @override
  List<String> get contents => [
        target,
        if (value != null) value.toString(),
        source,
      ];

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'date': date.toIso8601String(),
        'target': target,
        if (value != null) 'value': _encodeObject(value),
        'source': source,
      };
}

class NetworkLogarteEntry extends LogarteEntry {
  final NetworkRequestLogarteEntry request;
  final NetworkResponseLogarteEntry response;

  NetworkLogarteEntry({
    required this.request,
    required this.response,
    DateTime? date,
  }) : super(LogarteType.network, date: date);

  NetworkLogarteEntry.fromJson(Map<String, dynamic> json)
      : request = NetworkRequestLogarteEntry.fromJson(
            json['request'] as Map<String, dynamic>),
        response = NetworkResponseLogarteEntry.fromJson(
            json['response'] as Map<String, dynamic>),
        super(
          LogarteType.network,
          date: DateTime.parse(json['date'] as String),
        );

  @override
  List<String> get contents => [
        request.url,
        request.method,
        if (request.headers != null) request.headers!.toString(),
        if (request.body != null) request.body.toString(),
        if (request.sentAt != null) request.sentAt.toString(),
        if (response.statusCode != null) response.statusCode.toString(),
        if (response.headers != null) response.headers!.toString(),
        if (response.body != null) response.body.toString(),
        if (response.receivedAt != null) response.receivedAt.toString(),
      ];

  @override
  String toString() {
    return '''[${request.method}] ${request.url}

-- REQUEST --
HEADERS: ${request.headers.prettyJson}

BODY: ${request.body.prettyJson}

-- RESPONSE --
STATUS CODE: ${response.statusCode}

HEADERS: ${response.headers.prettyJson}

BODY: ${response.body.prettyJson}
''';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'date': date.toIso8601String(),
        'request': request.toJson(),
        'response': response.toJson(),
      };
}

class NetworkRequestLogarteEntry {
  final String url;
  final String method;
  final Map<String, dynamic>? headers;
  final Object? body;
  final DateTime? sentAt;

  const NetworkRequestLogarteEntry({
    required this.url,
    required this.method,
    required this.headers,
    this.body,
    this.sentAt,
  });

  NetworkRequestLogarteEntry.fromJson(Map<String, dynamic> json)
      : url = json['url'] as String,
        method = json['method'] as String,
        headers = (json['headers'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v),
        ),
        body = _decodeObject(json['body']),
        sentAt = json['sentAt'] != null
            ? DateTime.parse(json['sentAt'] as String)
            : null;

  Map<String, dynamic> toJson() => {
        'url': url,
        'method': method,
        if (headers != null) 'headers': headers,
        if (body != null) 'body': _encodeObject(body),
        if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
      };
}

class NetworkResponseLogarteEntry {
  final int? statusCode;
  final Map<String, String>? headers;
  final Object? body;
  final DateTime? receivedAt;

  NetworkResponseLogarteEntry({
    required this.statusCode,
    required this.headers,
    required this.body,
    this.receivedAt,
  });

  NetworkResponseLogarteEntry.fromJson(Map<String, dynamic> json)
      : statusCode = json['statusCode'] as int?,
        headers = (json['headers'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as String),
        ),
        body = _decodeObject(json['body']),
        receivedAt = json['receivedAt'] != null
            ? DateTime.parse(json['receivedAt'] as String)
            : null;

  Map<String, dynamic> toJson() => {
        if (statusCode != null) 'statusCode': statusCode,
        if (headers != null) 'headers': headers,
        if (body != null) 'body': _encodeObject(body),
        if (receivedAt != null) 'receivedAt': receivedAt!.toIso8601String(),
      };
}

enum NotificationEventType {
  received,
  tapped,
  subscribed,
  unsubscribed,
}

class NotificationLogarteEntry extends LogarteEntry {
  final NotificationEventType eventType;
  final String? messageId;
  final String? title;
  final String? body;
  final String? topic;
  final Map<String, dynamic>? data;
  final String? source;

  NotificationLogarteEntry({
    required this.eventType,
    this.messageId,
    this.title,
    this.body,
    this.topic,
    this.data,
    this.source,
    DateTime? date,
  }) : super(LogarteType.notification, date: date);

  NotificationLogarteEntry.fromJson(Map<String, dynamic> json)
      : eventType =
            NotificationEventType.values.byName(json['eventType'] as String),
        messageId = json['messageId'] as String?,
        title = json['title'] as String?,
        body = json['body'] as String?,
        topic = json['topic'] as String?,
        data = (json['data'] as Map<String, dynamic>?),
        source = json['source'] as String?,
        super(
          LogarteType.notification,
          date: DateTime.parse(json['date'] as String),
        );

  @override
  List<String> get contents => [
        eventType.name,
        if (title != null) title!,
        if (body != null) body!,
        if (topic != null) topic!,
        if (messageId != null) messageId!,
        if (source != null) source!,
        if (data != null) data.toString(),
      ];

  @override
  String toString() {
    return '''[${eventType.name.toUpperCase()}] $title
Topic: $topic
Body: $body
MessageId: $messageId
Source: $source
Data: $data
''';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'date': date.toIso8601String(),
        'eventType': eventType.name,
        if (messageId != null) 'messageId': messageId,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (topic != null) 'topic': topic,
        if (data != null) 'data': data,
        if (source != null) 'source': source,
      };
}

/// Encodes an arbitrary object for JSON storage.
/// If the object is already JSON-compatible (Map, List, String, num, bool),
/// it's returned as-is. Otherwise it's converted to a String.
Object _encodeObject(Object? value) {
  if (value == null) return 'null';
  if (value is String || value is num || value is bool) return value;
  if (value is Map || value is List) {
    try {
      jsonEncode(value);
      return value;
    } catch (_) {
      return value.toString();
    }
  }
  try {
    final encoded = jsonEncode(value);
    return jsonDecode(encoded);
  } catch (_) {
    return value.toString();
  }
}

/// Decodes a stored object back. JSON-compatible types come through as-is.
/// Strings that look like JSON are decoded.
Object? _decodeObject(Object? value) {
  if (value == null) return null;
  if (value is num || value is bool || value is Map || value is List) {
    return value;
  }
  if (value is String) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }
  return value;
}
