import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:trailify/trailify.dart';

import 'router.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _appRouter = AppRouter();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initTrailify();
  }

  Future<void> _initTrailify() async {
    final deviceInfo = await _gatherDeviceInfo();

    await Trailify.instance.init(
      appFlavor: 'development',
      appVersion: '1.0.0',
      platform: Platform.isIOS ? 'ios' : 'android',
      enableSync: false,
      password: '1234',
      ignorePassword: true,
      localOnlyEventTypes: {'screen_viewed'},
      deviceInfo: deviceInfo,
    );

    Trailify.instance.setUser(
      userId: 'USR_100042',
      email: 'demo@example.com',
      appId: 'trailify_example',
    );

    _seedDemoEvents();

    if (mounted) setState(() => _initialized = true);
  }

  Future<Map<String, dynamic>> _gatherDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final ios = await plugin.iosInfo;
      return {
        'model': ios.utsname.machine,
        'brand': 'Apple',
        'osVersion': 'iOS ${ios.systemVersion}',
        'isPhysicalDevice': ios.isPhysicalDevice,
        'locale': Platform.localeName,
      };
    } else {
      final android = await plugin.androidInfo;
      return {
        'model': android.model,
        'brand': android.brand,
        'osVersion': 'Android ${android.version.release}',
        'isPhysicalDevice': android.isPhysicalDevice,
        'locale': Platform.localeName,
      };
    }
  }

  void _seedDemoEvents() {
    Trailify.instance.log(
      eventType: 'api_request',
      payload: {
        'method': 'GET',
        'url': 'https://api.example.com/v1/users',
        'statusCode': 200,
        'durationMs': 142,
      },
    );

    Trailify.instance.log(
      eventType: 'api_request',
      payload: {
        'method': 'POST',
        'url': 'https://api.example.com/v1/messages',
        'statusCode': 201,
        'durationMs': 89,
        'requestBody': '{"text": "Hello!", "conversationId": 7}',
      },
    );

    Trailify.instance.log(
      eventType: 'api_error',
      payload: {
        'method': 'GET',
        'url': 'https://api.example.com/v1/posts/9999',
        'statusCode': 404,
        'durationMs': 35,
        'error': 'Not Found',
      },
    );

    Trailify.instance.notification(
      eventType: 'notification_received',
      messageId: 'msg_seed_001',
      title: 'New message from Sarah',
      body: 'Are you available for a call?',
      source: 'FCM',
      topic: 'direct_messages',
    );

    Trailify.instance.auth(
      eventType: 'auth_login',
      details: {'method': 'google', 'success': true},
    );

    Trailify.instance.userAction(
      action: 'send_message',
      context: {'conversationId': 7, 'textLength': 42, 'hasImages': false},
    );

    Trailify.instance.error(
      error: StateError('Cannot read property "name" of null'),
      context: 'user_profile_screen',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp.router(
      title: 'Trailify Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      routerConfig: _appRouter.config(
        navigatorObservers: () => [
          TrailifyNavigatorObserver(Trailify.instance),
        ],
      ),
    );
  }
}
