import 'package:flutter/material.dart';

import '../services/firestore_query_service.dart';

class DeviceProfileScreen extends StatefulWidget {
  final String deviceId;

  const DeviceProfileScreen({super.key, required this.deviceId});

  @override
  State<DeviceProfileScreen> createState() => _DeviceProfileScreenState();
}

class _DeviceProfileScreenState extends State<DeviceProfileScreen> {
  final _service = FirestoreQueryService();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _service.getDeviceProfile(widget.deviceId);
      setState(() { _profile = profile; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Device Profile', style: TextStyle(fontSize: 16)),
            Text(widget.deviceId.substring(0, 8), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed('/investigate', arguments: {'query': widget.deviceId});
            },
            icon: const Icon(Icons.search, size: 18),
            label: const Text('View events'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.device_unknown, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('No device profile found', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text('Device ID: ${widget.deviceId}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      );
    }

    final displayFields = [
      ('Device ID', _profile!['deviceId']),
      ('Model', _profile!['model']),
      ('Brand', _profile!['brand']),
      ('OS Version', _profile!['osVersion']),
      ('Physical Device', _profile!['isPhysicalDevice']),
      ('Screen', '${_profile!['screenWidth'] ?? '?'} x ${_profile!['screenHeight'] ?? '?'} @ ${_profile!['pixelRatio'] ?? '?'}x'),
      ('Locale', _profile!['locale']),
      ('Country', _profile!['country']),
      ('App Version', _profile!['appVersion']),
      ('App Flavor', _profile!['appFlavor']),
      ('Last Seen', _profile!['lastSeenAt']),
    ];

    final sessions = _profile!['sessions'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Device Info', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                const SizedBox(height: 12),
                ...displayFields.where((f) => f.$2 != null).map((f) => _row(f.$1, f.$2)),
              ],
            ),
          ),
        ),
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Sessions (${sessions.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  ...sessions.reversed.take(10).map((s) {
                    final sess = s as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule, size: 18),
                      title: Text(sess['sessionId'] as String? ?? '?', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                      subtitle: Text('${sess['startedAt'] ?? '?'} | v${sess['appVersion'] ?? '?'}', style: const TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.chevron_right, size: 16),
                      onTap: () {
                        final userId = _profile!['userId'] as String?;
                        final sessionId = sess['sessionId'] as String?;
                        if (userId != null && sessionId != null) {
                          Navigator.of(context).pushNamed('/session', arguments: {'userId': userId, 'sessionId': sessionId});
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
          Expanded(child: SelectableText('${value ?? '-'}', style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
