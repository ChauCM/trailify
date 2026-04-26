import 'package:flutter/material.dart';

import '../services/firestore_query_service.dart';
import '../widgets/event_detail_panel.dart';
import '../widgets/event_entry_item.dart';

class SessionTimelineScreen extends StatefulWidget {
  final String userId;
  final String sessionId;

  const SessionTimelineScreen({
    super.key,
    required this.userId,
    required this.sessionId,
  });

  @override
  State<SessionTimelineScreen> createState() => _SessionTimelineScreenState();
}

class _SessionTimelineScreenState extends State<SessionTimelineScreen> {
  final _service = FirestoreQueryService();
  List<Map<String, dynamic>>? _events;
  String? _error;
  Map<String, dynamic>? _selectedEvent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await _service.querySessionEvents(
        userId: widget.userId,
        sessionId: widget.sessionId,
      );
      setState(() => _events = events);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Session Timeline', style: TextStyle(fontSize: 16)),
            Text(
              '${widget.userId} / ${widget.sessionId.substring(0, 8)}...',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_events == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_events!.isEmpty) {
      return const Center(child: Text('No events in this session', style: TextStyle(color: Colors.grey)));
    }

    final isWide = MediaQuery.of(context).size.width > 900;

    if (isWide) {
      return Row(
        children: [
          Expanded(flex: 3, child: _buildTimeline()),
          if (_selectedEvent != null) Container(width: 1, color: Theme.of(context).dividerColor),
          if (_selectedEvent != null)
            Expanded(
              flex: 2,
              child: EventDetailPanel(
                event: _selectedEvent!,
                onClose: () => setState(() => _selectedEvent = null),
              ),
            ),
        ],
      );
    }

    return _buildTimeline();
  }

  Widget _buildTimeline() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _events!.length,
      itemBuilder: (context, index) {
        final event = _events![index];
        final eventType = event['eventType'] as String? ?? 'unknown';
        final color = colorForType(eventType);
        final isFirst = index == 0;
        final isLast = index == _events!.length - 1;
        final isSelected = _selectedEvent?['eventId'] == event['eventId'];

        return InkWell(
          onTap: () {
            if (MediaQuery.of(context).size.width > 900) {
              setState(() => _selectedEvent = event);
            } else {
              _showDetail(event);
            }
          },
          child: Container(
            color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withAlpha(50) : null,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 48,
                    child: Column(
                      children: [
                        if (!isFirst) Expanded(child: Container(width: 2, color: color.withAlpha(76))),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                        ),
                        if (!isLast) Expanded(child: Container(width: 2, color: color.withAlpha(76))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(iconForType(eventType), size: 16, color: color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  EventEntryItem.summaryLine(eventType, event['payload'] as Map<String, dynamic>? ?? {}),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            EventEntryItem.formatTimestamp(event),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDetail(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: EventDetailPanel(event: event, onClose: () => Navigator.of(context).pop()),
      ),
    );
  }
}
