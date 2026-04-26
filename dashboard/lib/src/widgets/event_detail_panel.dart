import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EventDetailPanel extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onSessionTap;
  final VoidCallback? onDeviceTap;
  final VoidCallback? onClose;

  const EventDetailPanel({
    super.key,
    required this.event,
    this.onSessionTap,
    this.onDeviceTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final eventType = event['eventType'] as String? ?? 'unknown';
    final payload = event['payload'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, eventType),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionHeader('Event Info'),
              _KeyValue('eventType', eventType),
              _KeyValue('eventId', event['eventId']),
              _KeyValue('timestamp', _formatTs(event['timestamp'])),
              const SizedBox(height: 16),
              const _SectionHeader('Identity'),
              _KeyValue('userId', event['userId']),
              _KeyValue('userEmail', event['userEmail']),
              _TappableKeyValue(
                label: 'deviceId',
                value: event['deviceId'],
                onTap: onDeviceTap,
              ),
              _TappableKeyValue(
                label: 'sessionId',
                value: event['sessionId'],
                onTap: onSessionTap,
              ),
              _KeyValue('appId', event['appId']),
              _KeyValue('appFlavor', event['appFlavor']),
              _KeyValue('platform', event['platform']),
              _KeyValue('appVersion', event['appVersion']),
              const SizedBox(height: 16),
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
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String eventType) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(eventType, style: theme.textTheme.titleMedium),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Copy JSON',
            onPressed: () {
              final clean = Map<String, dynamic>.from(event)
                ..remove('_docId')
                ..remove('_docRef');
              final text = const JsonEncoder.withIndent('  ').convert(clean);
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }

  String _formatTs(dynamic ts) {
    if (ts == null) return '-';
    try {
      final dt = DateTime.parse(ts as String).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts.toString();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.blueGrey, letterSpacing: 0.5),
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
      display = '-';
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
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: SelectableText(display, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _TappableKeyValue extends StatelessWidget {
  final String label;
  final dynamic value;
  final VoidCallback? onTap;
  const _TappableKeyValue({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (value == null || onTap == null) return _KeyValue(label, value);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(
                value.toString(),
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                  width: 130,
                  child: Text(widget.label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(preview, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(left: 16, bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withAlpha(38)),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(widget.value),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
      ],
    );
  }
}
