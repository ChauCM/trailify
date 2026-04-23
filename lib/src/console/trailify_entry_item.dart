import 'package:flutter/material.dart';
import 'event_detail_screen.dart';

class TrailifyEntryItem extends StatelessWidget {
  final Map<String, dynamic> event;

  const TrailifyEntryItem({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final eventType = event['eventType'] as String? ?? 'unknown';
    final payload = event['payload'] as Map<String, dynamic>? ?? {};
    final isApi = eventType == 'api_request' || eventType == 'api_error';

    return ListTile(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: event),
            settings: const RouteSettings(name: '/trailify_event_detail'),
          ),
        );
      },
      leading: _EventIcon(eventType: eventType),
      title: Text(
        _summaryLine(eventType, payload),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14.0),
      ),
      subtitle: Text(
        _formatTimestamp(event),
        style: const TextStyle(fontSize: 12.0, color: Colors.grey),
      ),
      trailing: isApi
          ? _ApiTrailing(payload: payload)
          : const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
    );
  }

  static String _summaryLine(String type, Map<String, dynamic> payload) {
    switch (type) {
      case 'api_request':
      case 'api_error':
        final method = payload['method'] ?? '';
        final url = payload['url'] ?? '';
        final status = payload['statusCode'];
        return '[$method] $url${status != null ? ' → $status' : ''}';
      case 'notification_received':
      case 'notification_tapped':
        return payload['title'] as String? ??
            payload['topic'] as String? ??
            type;
      case 'notification_subscribed':
      case 'notification_unsubscribed':
        return '${type.replaceAll('notification_', '')} ${payload['topic'] ?? ''}';
      case 'user_action':
        return payload['action'] as String? ?? type;
      case 'screen_viewed':
        return payload['screenName'] as String? ?? type;
      case 'auth_login':
        final ok = payload['success'] == true ? 'success' : 'failed';
        return 'Login ($ok)';
      case 'auth_logout':
        return 'Logout (${payload['reason'] ?? ''})';
      case 'auth_token_refresh':
        final ok = payload['success'] == true ? 'success' : 'failed';
        return 'Token refresh ($ok)';
      case 'error':
        return payload['error'] as String? ?? 'Error';
      default:
        return type;
    }
  }

  static String _formatTimestamp(Map<String, dynamic> event) {
    final localTs = event['localTimestamp'] as String?;
    final utcTs = event['timestamp'] as String?;

    DateTime? dt;
    if (localTs != null && localTs.isNotEmpty) {
      try {
        dt = DateTime.parse(localTs);
      } catch (_) {}
    }
    if (dt == null && utcTs != null && utcTs.isNotEmpty) {
      try {
        dt = DateTime.parse(utcTs).toLocal();
      } catch (_) {}
    }
    if (dt == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(dt.year, dt.month, dt.day);
    final time = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';

    if (eventDay == today) return time;

    if (eventDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $time';
    }

    final diff = today.difference(eventDay).inDays;
    if (diff < 7 && diff > 0) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[dt.weekday - 1]} $time';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day} $time';
  }
}

// ── API trailing badge ──

class _ApiTrailing extends StatelessWidget {
  final Map<String, dynamic> payload;

  const _ApiTrailing({required this.payload});

  @override
  Widget build(BuildContext context) {
    final statusCode = payload['statusCode'];
    final durationMs = payload['durationMs'];
    final code = statusCode is int ? statusCode : int.tryParse('$statusCode');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (code != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor(code).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$code',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _statusColor(code),
              ),
            ),
          ),
        if (durationMs != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${durationMs}ms',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  static Color _statusColor(int code) {
    if (code < 300) return Colors.green;
    if (code < 400) return Colors.orange;
    return Colors.red;
  }
}

// ── Event icon ──

class _EventIcon extends StatelessWidget {
  final String eventType;

  const _EventIcon({Key? key, required this.eventType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForType(eventType);
    final color = _colorForType(eventType);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'api_request':
        return Icons.public;
      case 'api_error':
        return Icons.public_off;
      case 'notification_received':
        return Icons.notifications_active;
      case 'notification_tapped':
        return Icons.touch_app;
      case 'notification_subscribed':
        return Icons.notifications;
      case 'notification_unsubscribed':
        return Icons.notifications_off;
      case 'user_action':
        return Icons.touch_app_rounded;
      case 'screen_viewed':
        return Icons.pageview;
      case 'auth_login':
        return Icons.login;
      case 'auth_logout':
        return Icons.logout;
      case 'auth_token_refresh':
        return Icons.refresh;
      case 'error':
        return Icons.error;
      default:
        return Icons.info_outline;
    }
  }

  static Color _colorForType(String type) {
    switch (type) {
      case 'api_request':
        return Colors.green;
      case 'api_error':
        return Colors.red;
      case 'notification_received':
        return Colors.green;
      case 'notification_tapped':
        return Colors.blue;
      case 'notification_subscribed':
      case 'notification_unsubscribed':
        return Colors.orange;
      case 'user_action':
        return Colors.purple;
      case 'screen_viewed':
        return Colors.teal;
      case 'auth_login':
      case 'auth_logout':
      case 'auth_token_refresh':
        return Colors.indigo;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
