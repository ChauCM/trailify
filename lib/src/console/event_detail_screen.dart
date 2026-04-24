import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../trailify.dart';
import '../trailify_device_profile.dart';
import 'trailify_theme_wrapper.dart';

class EventDetailScreen extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final eventType = event['eventType'] as String? ?? 'unknown';
    final payload = event['payload'] as Map<String, dynamic>? ?? {};

    return TrailifyThemeWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(eventType),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy JSON',
              onPressed: () {
                final text =
                    const JsonEncoder.withIndent('  ').convert(event);
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader('Event Info'),
            _KeyValue('eventType', eventType),
            _KeyValue('eventId', event['eventId']),
            _TimestampRow(event: event),
            _KeyValue('syncStatus', event['syncStatus']),
            const SizedBox(height: 16),
            const _SectionHeader('Identity'),
            _KeyValue('userId', event['userId']),
            _KeyValue('userEmail', event['userEmail']),
            _KeyValue('deviceId', event['deviceId']),
            _KeyValue('sessionId', event['sessionId']),
            _KeyValue('appId', event['appId']),
            _KeyValue('appFlavor', event['appFlavor']),
            _KeyValue('platform', event['platform']),
            _KeyValue('appVersion', event['appVersion']),
            const SizedBox(height: 16),
            _DeviceSection(deviceId: event['deviceId'] as String?),
            const _SectionHeader('Payload'),
            ...payload.entries.map((e) {
              if (e.value is Map || e.value is List) {
                return _CollapsibleJsonField(label: e.key, value: e.value);
              }
              return _KeyValue(e.key, e.value);
            }),
          ],
        ),
      ),
    );
  }
}

// ── Dual timestamp row ──

class _TimestampRow extends StatelessWidget {
  final Map<String, dynamic> event;

  const _TimestampRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final utcTs = event['timestamp'] as String?;
    final localTs = event['localTimestamp'] as String?;
    final tzOffset = event['timezoneOffset'];
    final tzName = event['timezoneName'] as String?;

    String utcDisplay = utcTs ?? '—';
    String localDisplay = '—';

    if (localTs != null && localTs.isNotEmpty) {
      try {
        final dt = DateTime.parse(localTs);
        localDisplay = _formatFull(dt);
        if (tzName != null) {
          final offsetStr = _formatOffset(tzOffset is int ? tzOffset : 0);
          localDisplay += ' $tzName ($offsetStr)';
        }
      } catch (_) {
        localDisplay = localTs;
      }
    } else if (utcTs != null && utcTs.isNotEmpty) {
      try {
        final dt = DateTime.parse(utcTs).toLocal();
        localDisplay = _formatFull(dt);
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KeyValue('timestamp (UTC)', utcDisplay),
        _KeyValue('timestamp (local)', localDisplay),
      ],
    );
  }

  static String _formatFull(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  static String _formatOffset(int minutes) {
    final sign = minutes >= 0 ? '+' : '-';
    final abs = minutes.abs();
    final h = abs ~/ 60;
    final m = abs % 60;
    return 'UTC$sign${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

// ── Collapsible JSON tree ──

class _CollapsibleJsonField extends StatefulWidget {
  final String label;
  final dynamic value;

  const _CollapsibleJsonField({required this.label, required this.value});

  @override
  State<_CollapsibleJsonField> createState() => _CollapsibleJsonFieldState();
}

class _CollapsibleJsonFieldState extends State<_CollapsibleJsonField> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final preview = widget.value is Map
        ? '{${(widget.value as Map).length} fields}'
        : '[${(widget.value as List).length} items]';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    preview,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(left: 16, bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: widget.value is Map
                ? _JsonMapView(data: widget.value as Map<String, dynamic>)
                : _JsonListView(data: widget.value as List),
          ),
      ],
    );
  }
}

class _JsonMapView extends StatelessWidget {
  final Map<String, dynamic> data;
  const _JsonMapView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((e) {
        if (e.value is Map || e.value is List) {
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _CollapsibleJsonField(label: e.key, value: e.value),
          );
        }
        return _KeyValue(e.key, e.value);
      }).toList(),
    );
  }
}

class _JsonListView extends StatelessWidget {
  final List data;
  const _JsonListView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.asMap().entries.map((e) {
        if (e.value is Map || e.value is List) {
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _CollapsibleJsonField(label: '[${e.key}]', value: e.value),
          );
        }
        return _KeyValue('[${e.key}]', e.value);
      }).toList(),
    );
  }
}

// ── Device section ──

class _DeviceSection extends StatefulWidget {
  final String? deviceId;

  const _DeviceSection({required this.deviceId});

  @override
  State<_DeviceSection> createState() => _DeviceSectionState();
}

class _DeviceSectionState extends State<_DeviceSection> {
  Map<String, dynamic>? _profile;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (widget.deviceId == null) {
      setState(() => _loaded = true);
      return;
    }
    try {
      final profile = await TrailifyDeviceProfile.getLocal(
        Trailify.instance.store,
        widget.deviceId!,
      );
      if (mounted) setState(() { _profile = profile; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _profile == null) return const SizedBox.shrink();

    final display = [
      'model', 'brand', 'osVersion', 'isPhysicalDevice',
      'screenWidth', 'screenHeight', 'pixelRatio',
      'locale', 'country',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Device'),
        ...display
            .where((k) => _profile!.containsKey(k) && _profile![k] != null)
            .map((k) => _KeyValue(k, _profile![k])),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Shared widgets ──

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.blueGrey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final dynamic value;

  const _KeyValue(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    String display;
    if (value == null) {
      display = '—';
    } else if (value is Map || value is List) {
      try {
        display = const JsonEncoder.withIndent('  ').convert(value);
      } catch (_) {
        display = value.toString();
      }
    } else {
      display = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              display,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
