import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth/auth_gate.dart';
import 'config/connect_project_screen.dart';
import 'config/firebase_config_provider.dart';
import 'widgets/trailify_logo.dart';
import 'screens/device_profile_screen.dart';
import 'screens/error_dashboard_screen.dart';
import 'screens/session_timeline_screen.dart';
import 'screens/user_investigation_screen.dart';

class TrailifyDashboardApp extends StatefulWidget {
  const TrailifyDashboardApp({super.key});

  @override
  State<TrailifyDashboardApp> createState() => _TrailifyDashboardAppState();
}

class _TrailifyDashboardAppState extends State<TrailifyDashboardApp> {
  bool _firebaseReady = false;
  bool _needsConfig = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _tryInitFirebase();
  }

  Future<void> _tryInitFirebase() async {
    final config = FirebaseConfigProvider.getSavedConfig();
    if (config == null) {
      setState(() => _needsConfig = true);
      return;
    }

    try {
      await Firebase.initializeApp(
        options: FirebaseConfigProvider.toFirebaseOptions(config),
      );
      setState(() => _firebaseReady = true);
    } catch (e) {
      setState(() => _initError = e.toString());
    }
  }

  void _onConfigured() {
    setState(() { _needsConfig = false; _initError = null; });
    _tryInitFirebase();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trailify Dashboard',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: _buildHome(),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Widget _buildHome() {
    if (_initError != null) {
      return _ErrorStartup(
        error: _initError!,
        onRetry: () {
          FirebaseConfigProvider.clearConfig();
          setState(() { _initError = null; _needsConfig = true; });
        },
      );
    }

    if (_needsConfig) {
      return ConnectProjectScreen(onConnected: _onConfigured);
    }

    if (!_firebaseReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AuthGate(child: const _DashboardShell());
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/session':
        final args = settings.arguments as Map<String, String>?;
        if (args == null) return null;
        return MaterialPageRoute(
          builder: (_) => SessionTimelineScreen(
            userId: args['userId']!,
            sessionId: args['sessionId']!,
          ),
        );
      case '/device':
        final args = settings.arguments as Map<String, String>?;
        if (args == null) return null;
        return MaterialPageRoute(
          builder: (_) => DeviceProfileScreen(deviceId: args['deviceId']!),
        );
      case '/investigate':
        final args = settings.arguments as Map<String, String>?;
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: UserInvestigationScreen(initialQuery: args?['query']),
          ),
        );
      default:
        return null;
    }
  }

  ThemeData _buildTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light(useMaterial3: true)
        : ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A6CF7),
        brightness: brightness,
      ),
    );
  }
}

class _DashboardShell extends StatefulWidget {
  const _DashboardShell();

  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final user = FirebaseAuth.instance.currentUser;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const TrailifyLogo(size: 28),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SettingsMenu(user: user),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.search), label: Text('Investigate')),
                NavigationRailDestination(icon: Icon(Icons.error_outline), label: Text('Errors')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _pages[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Investigate'),
          NavigationDestination(icon: Icon(Icons.error_outline), label: 'Errors'),
        ],
      ),
    );
  }

  static final _pages = <Widget>[
    const UserInvestigationScreen(),
    const ErrorDashboardScreen(),
  ];
}

class _SettingsMenu extends StatelessWidget {
  final User? user;
  const _SettingsMenu({this.user});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      tooltip: 'Settings',
      onSelected: (value) async {
        switch (value) {
          case 'disconnect':
            FirebaseConfigProvider.clearConfig();
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            }
          case 'signout':
            await FirebaseAuth.instance.signOut();
        }
      },
      itemBuilder: (_) => [
        if (user != null)
          PopupMenuItem(
            enabled: false,
            child: Text(user!.email ?? 'Unknown', style: const TextStyle(fontSize: 12)),
          ),
        const PopupMenuItem(value: 'signout', child: Text('Sign out')),
        const PopupMenuItem(value: 'disconnect', child: Text('Disconnect project')),
      ],
    );
  }
}

class _ErrorStartup extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorStartup({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Failed to initialize Firebase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(error, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Re-enter config')),
            ],
          ),
        ),
      ),
    );
  }
}
