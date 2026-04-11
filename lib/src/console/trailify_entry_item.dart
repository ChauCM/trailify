import 'package:flutter/material.dart';
import 'event_detail_screen.dart';

class TrailifyEntryItem extends StatelessWidget {
  final Map<String, dynamic> event;

  const TrailifyEntryItem({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final eventType = event['eventType'] as String? ?? 'unknown';
    final payload = event['payload'] as Map<String, dynamic>? ?? {};
    final timestamp = event['timestamp'] as String? ?? '';

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
        _formatTimestamp(timestamp),
        style: const TextStyle(fontSize: 12.0, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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

  static String _formatTimestamp(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _EventIcon extends StatelessWidget {
  final String eventType;

  const _EventIcon({Key? key, required this.eventType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForType(eventType);
    final color = _colorForType(eventType);
    return Icon(iconData, color: color, size: 22);
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
