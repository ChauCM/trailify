import 'package:flutter/material.dart';

class EventEntryItem extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onTap;
  final VoidCallback? onSessionTap;
  final VoidCallback? onDeviceTap;

  const EventEntryItem({
    super.key,
    required this.event,
    this.onTap,
    this.onSessionTap,
    this.onDeviceTap,
  });

  @override
  Widget build(BuildContext context) {
    final eventType = event['eventType'] as String? ?? 'unknown';
    final payload = event['payload'] as Map<String, dynamic>? ?? {};
    final isApi = eventType == 'api_request' || eventType == 'api_error';

    return ListTile(
      onTap: onTap,
      leading: _EventIcon(eventType: eventType),
      title: Text(
        summaryLine(eventType, payload),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14.0),
      ),
      subtitle: Row(
        children: [
          Text(
            formatTimestamp(event),
            style: const TextStyle(fontSize: 12.0, color: Colors.grey),
          ),
          if (event['userId'] != null) ...[
            const SizedBox(width: 8),
            Text(
              event['userId'] as String,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
      trailing: isApi
          ? _ApiTrailing(payload: payload)
          : const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
    );
  }

  static String summaryLine(String type, Map<String, dynamic> payload) {
    switch (type) {
      case 'api_request':
      case 'api_error':
        final method = payload['method'] ?? '';
        final url = payload['url'] ?? '';
        final status = payload['statusCode'];
        return '[$method] $url${status != null ? ' -> $status' : ''}';
      case 'notification_received':
      case 'notification_tapped':
        return payload['title'] as String? ?? payload['topic'] as String? ?? type;
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

  static String formatTimestamp(Map<String, dynamic> event) {
    final ts = event['timestamp'] as String?;
    if (ts == null || ts.isEmpty) return '';

    DateTime? dt;
    try {
      dt = DateTime.parse(ts).toLocal();
    } catch (_) {
      return '';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(dt.year, dt.month, dt.day);
    final time = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';

    if (eventDay == today) return time;
    if (eventDay == today.subtract(const Duration(days: 1))) return 'Yesterday $time';

    final diff = today.difference(eventDay).inDays;
    if (diff < 7 && diff > 0) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[dt.weekday - 1]} $time';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day} $time';
  }
}

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
              color: _statusColor(code).withAlpha(38),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$code',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor(code)),
            ),
          ),
        if (durationMs != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('${durationMs}ms', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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

class _EventIcon extends StatelessWidget {
  final String eventType;
  const _EventIcon({required this.eventType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colorForType(eventType).withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconForType(eventType), color: colorForType(eventType), size: 20),
    );
  }

  static IconData iconForType(String type) {
    switch (type) {
      case 'api_request': return Icons.public;
      case 'api_error': return Icons.public_off;
      case 'notification_received': return Icons.notifications_active;
      case 'notification_tapped': return Icons.touch_app;
      case 'notification_subscribed': return Icons.notifications;
      case 'notification_unsubscribed': return Icons.notifications_off;
      case 'user_action': return Icons.touch_app_rounded;
      case 'screen_viewed': return Icons.pageview;
      case 'auth_login': return Icons.login;
      case 'auth_logout': return Icons.logout;
      case 'auth_token_refresh': return Icons.refresh;
      case 'error': return Icons.error;
      default: return Icons.info_outline;
    }
  }

  static Color colorForType(String type) {
    switch (type) {
      case 'api_request': return Colors.green;
      case 'api_error': return Colors.red;
      case 'notification_received': return Colors.green;
      case 'notification_tapped': return Colors.blue;
      case 'notification_subscribed':
      case 'notification_unsubscribed': return Colors.orange;
      case 'user_action': return Colors.purple;
      case 'screen_viewed': return Colors.teal;
      case 'auth_login':
      case 'auth_logout':
      case 'auth_token_refresh': return Colors.indigo;
      case 'error': return Colors.red;
      default: return Colors.grey;
    }
  }
}

IconData iconForType(String type) => _EventIcon.iconForType(type);
Color colorForType(String type) => _EventIcon.colorForType(type);
