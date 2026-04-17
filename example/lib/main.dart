import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:trailify/trailify.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trailify Example',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey.shade900,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Dio _dio;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initTrailify();
  }

  Future<void> _initTrailify() async {
    await Trailify.instance.init(
      appFlavor: 'development',
      appVersion: '1.0.0',
      platform: 'ios',
      enableSync: false,
      password: '1234',
      ignorePassword: true,
      localOnlyEventTypes: {'screen_viewed'},
    );

    _dio = Dio()
      ..interceptors.add(
        TrailifyDioInterceptor(
          Trailify.instance,
          captureSuccessBodies: true,
          excludePatterns: [RegExp(r'/health')],
        ),
      );

    Trailify.instance.setUser(
      userId: 'USR_100042',
      email: 'demo@example.com',
      appId: 'trailify_example',
    );

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _dio.close();
    Trailify.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trailify Example')),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  TrailifyMagicalTap(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const ListTile(
                        leading: Icon(Icons.touch_app_rounded),
                        title: Text('Trailify Console'),
                        subtitle:
                            Text('Tap 10x to open, or long press below.'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onLongPress: () {
                      Trailify.instance.openConsole(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const ListTile(
                        leading: Icon(Icons.terminal),
                        title: Text('Open Console'),
                        subtitle: Text('Long press to open directly.'),
                      ),
                    ),
                  ),
                  const Divider(height: 40),
                  Text('HTTP Requests',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: 'GET /posts',
                    onPressed: () => _dio.get(
                        'https://jsonplaceholder.typicode.com/posts'),
                  ),
                  _ActionButton(
                    label: 'POST /posts',
                    onPressed: () => _dio.post(
                      'https://jsonplaceholder.typicode.com/posts',
                      data: {'title': 'test', 'body': 'hello', 'userId': 1},
                    ),
                  ),
                  _ActionButton(
                    label: 'GET /404',
                    onPressed: () async {
                      try {
                        await _dio.get(
                            'https://jsonplaceholder.typicode.com/posts/9999');
                      } catch (_) {}
                    },
                  ),
                  const Divider(height: 40),
                  Text('Manual Events',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: 'User Action',
                    icon: Icons.touch_app,
                    onPressed: () {
                      Trailify.instance.userAction(
                        action: 'tap_buy_button',
                        context: {'productId': 42, 'price': 19.99},
                      );
                    },
                  ),
                  _ActionButton(
                    label: 'Screen View',
                    icon: Icons.pageview,
                    onPressed: () {
                      Trailify.instance.screenView(
                        screenName: 'ProductDetail',
                        arguments: {'productId': 42},
                      );
                    },
                  ),
                  _ActionButton(
                    label: 'Auth Login',
                    icon: Icons.login,
                    onPressed: () {
                      Trailify.instance.auth(
                        eventType: 'auth_login',
                        details: {'method': 'google', 'success': true},
                      );
                    },
                  ),
                  _ActionButton(
                    label: 'Error',
                    icon: Icons.error_outline,
                    onPressed: () {
                      try {
                        throw Exception('Something went wrong');
                      } catch (e, s) {
                        Trailify.instance.error(
                          error: e,
                          stackTrace: s,
                          context: 'example_screen',
                        );
                      }
                    },
                  ),
                  _ActionButton(
                    label: 'Notification',
                    icon: Icons.notifications,
                    onPressed: () {
                      Trailify.instance.notification(
                        eventType: 'notification_received',
                        title: 'New message from John',
                        body: 'Hey, check out this deal!',
                        source: 'FCM',
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.http),
        label: Text(label),
      ),
    );
  }
}
