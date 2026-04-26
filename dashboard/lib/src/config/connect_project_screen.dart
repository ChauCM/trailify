import 'package:flutter/material.dart';

import 'firebase_config_provider.dart';

class ConnectProjectScreen extends StatefulWidget {
  final VoidCallback onConnected;

  const ConnectProjectScreen({super.key, required this.onConnected});

  @override
  State<ConnectProjectScreen> createState() => _ConnectProjectScreenState();
}

class _ConnectProjectScreenState extends State<ConnectProjectScreen> {
  final _controller = TextEditingController();
  String? _error;

  static const _exampleConfig = '''{
  "apiKey": "AIzaSy...",
  "authDomain": "your-project.firebaseapp.com",
  "projectId": "your-project-id",
  "storageBucket": "your-project.appspot.com",
  "messagingSenderId": "123456789",
  "appId": "1:123456789:web:abc123"
}''';

  void _connect() {
    final parsed = FirebaseConfigProvider.parseConfigInput(_controller.text);
    if (parsed == null) {
      setState(() => _error = 'Invalid config. Paste the Firebase web app config JSON.');
      return;
    }
    FirebaseConfigProvider.saveConfig(parsed);
    widget.onConnected();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.route_rounded, size: 32, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text('Trailify Dashboard', style: theme.textTheme.headlineMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect to your Firebase project to start investigating events.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                Text('Firebase Config', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Paste your Firebase web app config from Firebase Console > Project Settings > General > Your apps > Web app.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  maxLines: 10,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: _exampleConfig,
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _connect,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect Project'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
