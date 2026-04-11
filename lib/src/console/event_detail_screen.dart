import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              onPressed: () {
                final text = const JsonEncoder.withIndent('  ').convert(event);
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
            _KeyValue('timestamp', event['timestamp']),
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
            const _SectionHeader('Payload'),
            ...payload.entries.map((e) => _KeyValue(e.key, e.value)),
          ],
        ),
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
            child: Text(
              display,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
