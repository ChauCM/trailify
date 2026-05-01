import 'package:auto_route/auto_route.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:trailify/trailify.dart';

@RoutePage()
class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = Dio()
      ..interceptors.add(
        TrailifyDioInterceptor(
          Trailify.instance,
          captureSuccessBodies: true,
          excludePatterns: [RegExp(r'/health')],
        ),
      );
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playground')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'HTTP Requests',
            icon: Icons.public,
            color: Colors.green,
            children: [
              _ActionTile(
                label: 'GET /posts',
                subtitle: 'Fetch list of posts',
                icon: Icons.download_rounded,
                onTap: () =>
                    _dio.get('https://jsonplaceholder.typicode.com/posts'),
              ),
              _ActionTile(
                label: 'GET /users/1',
                subtitle: 'Fetch single user',
                icon: Icons.person_rounded,
                onTap: () =>
                    _dio.get('https://jsonplaceholder.typicode.com/users/1'),
              ),
              _ActionTile(
                label: 'POST /posts',
                subtitle: 'Create a new post',
                icon: Icons.upload_rounded,
                onTap: () => _dio.post(
                  'https://jsonplaceholder.typicode.com/posts',
                  data: {
                    'title': 'Hello Trailify',
                    'body': 'Testing audit trail',
                    'userId': 1
                  },
                ),
              ),
              _ActionTile(
                label: 'GET /posts/9999',
                subtitle: 'Trigger 404 error',
                icon: Icons.error_outline_rounded,
                color: Colors.red,
                onTap: () async {
                  try {
                    await _dio.get(
                        'https://jsonplaceholder.typicode.com/posts/9999');
                  } catch (_) {}
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Notifications',
            icon: Icons.notifications_rounded,
            color: Colors.amber,
            children: [
              _ActionTile(
                label: 'Notification Received',
                subtitle: 'Simulate FCM push',
                icon: Icons.notifications_active_rounded,
                onTap: () => Trailify.instance.notification(
                  eventType: 'notification_received',
                  messageId: 'msg_${DateTime.now().millisecondsSinceEpoch}',
                  title: 'New message from John',
                  body: 'Hey, check out this deal!',
                  source: 'FCM',
                  topic: 'promotions',
                ),
              ),
              _ActionTile(
                label: 'Notification Tapped',
                subtitle: 'Simulate user opening notification',
                icon: Icons.touch_app_rounded,
                onTap: () => Trailify.instance.notification(
                  eventType: 'notification_tapped',
                  messageId: 'msg_001',
                  title: 'New message from John',
                  body: 'Hey, check out this deal!',
                  source: 'FCM',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Auth Events',
            icon: Icons.lock_rounded,
            color: Colors.indigo,
            children: [
              _ActionTile(
                label: 'Login Success',
                subtitle: 'Google login event',
                icon: Icons.login_rounded,
                onTap: () => Trailify.instance.auth(
                  eventType: 'auth_login',
                  details: {'method': 'google', 'success': true},
                ),
              ),
              _ActionTile(
                label: 'Login Failed',
                subtitle: 'Wrong password event',
                icon: Icons.lock_open_rounded,
                color: Colors.red,
                onTap: () => Trailify.instance.auth(
                  eventType: 'auth_login',
                  details: {
                    'method': 'email',
                    'success': false,
                    'error': 'invalid_credentials'
                  },
                ),
              ),
              _ActionTile(
                label: 'Logout',
                subtitle: 'User-initiated logout',
                icon: Icons.logout_rounded,
                onTap: () => Trailify.instance.auth(
                  eventType: 'auth_logout',
                  details: {'reason': 'user_initiated'},
                ),
              ),
              _ActionTile(
                label: 'Token Refresh',
                subtitle: 'Auto token refresh',
                icon: Icons.refresh_rounded,
                onTap: () => Trailify.instance.auth(
                  eventType: 'auth_token_refresh',
                  details: {'success': true},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'User Actions',
            icon: Icons.touch_app_rounded,
            color: Colors.purple,
            children: [
              _ActionTile(
                label: 'Tap Buy Button',
                subtitle: 'Track purchase intent',
                icon: Icons.shopping_cart_rounded,
                onTap: () => Trailify.instance.userAction(
                  action: 'tap_buy_button',
                  details: {'productId': 42, 'price': 19.99},
                ),
              ),
              _ActionTile(
                label: 'Send Message',
                subtitle: 'Track chat message sent',
                icon: Icons.send_rounded,
                onTap: () => Trailify.instance.userAction(
                  action: 'send_message',
                  details: {
                    'conversationId': 7,
                    'textLength': 156,
                    'hasImages': false
                  },
                ),
              ),
              _ActionTile(
                label: 'Toggle Favorite',
                subtitle: 'Track favorite action',
                icon: Icons.favorite_rounded,
                onTap: () => Trailify.instance.userAction(
                  action: 'toggle_favorite',
                  details: {'itemId': 99, 'isFavorite': true},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Errors',
            icon: Icons.error_rounded,
            color: Colors.red,
            children: [
              _ActionTile(
                label: 'Caught Exception',
                subtitle: 'Try/catch error logging',
                icon: Icons.bug_report_rounded,
                onTap: () {
                  try {
                    throw const FormatException('Invalid email format', 'abc@');
                  } catch (e, s) {
                    Trailify.instance.error(
                      error: e,
                      stackTrace: s,
                      context: 'playground_screen',
                    );
                  }
                },
              ),
              _ActionTile(
                label: 'Null Reference',
                subtitle: 'Simulated null error',
                icon: Icons.do_not_disturb_rounded,
                onTap: () {
                  try {
                    throw StateError('Cannot access property of null');
                  } catch (e, s) {
                    Trailify.instance.error(
                      error: e,
                      stackTrace: s,
                      context: 'data_processing',
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing:
          Icon(Icons.play_arrow_rounded, color: Colors.grey[400], size: 20),
      onTap: onTap,
    );
  }
}
