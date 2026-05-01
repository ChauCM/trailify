import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:trailify/trailify.dart';

@RoutePage()
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = true;
  bool _notifications = true;
  bool _analytics = false;
  bool _biometrics = false;

  void _toggle(String setting, bool value, void Function(bool) setter) {
    setState(() => setter(value));
    Trailify.instance.userAction(
      action: 'toggle_setting',
      details: {'setting': setting, 'enabled': value},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark color scheme'),
            secondary: const Icon(Icons.dark_mode_rounded),
            value: _darkMode,
            onChanged: (v) =>
                _toggle('dark_mode', v, (val) => _darkMode = val),
          ),
          const Divider(height: 0),
          const _SectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive push notifications'),
            secondary: const Icon(Icons.notifications_rounded),
            value: _notifications,
            onChanged: (v) =>
                _toggle('push_notifications', v, (val) => _notifications = val),
          ),
          const Divider(height: 0),
          const _SectionHeader('Privacy'),
          SwitchListTile(
            title: const Text('Analytics'),
            subtitle: const Text('Share usage analytics'),
            secondary: const Icon(Icons.analytics_rounded),
            value: _analytics,
            onChanged: (v) =>
                _toggle('analytics', v, (val) => _analytics = val),
          ),
          SwitchListTile(
            title: const Text('Biometric Lock'),
            subtitle: const Text('Require Face ID / fingerprint'),
            secondary: const Icon(Icons.fingerprint_rounded),
            value: _biometrics,
            onChanged: (v) =>
                _toggle('biometric_lock', v, (val) => _biometrics = val),
          ),
          const Divider(height: 0),
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_rounded),
            title: const Text('Profile'),
            subtitle: const Text('demo@example.com'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Trailify.instance.userAction(
                action: 'view_profile',
                details: {'source': 'settings'},
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () {
              Trailify.instance.auth(
                eventType: 'auth_logout',
                details: {'reason': 'user_initiated', 'source': 'settings'},
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
