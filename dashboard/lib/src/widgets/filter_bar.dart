import 'package:flutter/material.dart';

class FilterState {
  final Duration? timeRange;
  final Set<String> httpStatusRanges;

  const FilterState({this.timeRange, this.httpStatusRanges = const {}});

  int get activeCount => (timeRange != null ? 1 : 0) + (httpStatusRanges.isNotEmpty ? 1 : 0);

  FilterState copyWith({
    Duration? Function()? timeRange,
    Set<String>? httpStatusRanges,
  }) {
    return FilterState(
      timeRange: timeRange != null ? timeRange() : this.timeRange,
      httpStatusRanges: httpStatusRanges ?? this.httpStatusRanges,
    );
  }
}

class FilterBar extends StatelessWidget {
  final FilterState filters;
  final bool showHttpFilter;
  final ValueChanged<FilterState> onChanged;

  const FilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
    this.showHttpFilter = false,
  });

  static const _timePresets = <String, Duration?>{
    'All time': null,
    '1 hour': Duration(hours: 1),
    '24 hours': Duration(hours: 24),
    '7 days': Duration(days: 7),
    '30 days': Duration(days: 30),
  };

  static const _httpRanges = ['2xx', '3xx', '4xx', '5xx'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              const Text('Time range', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const Spacer(),
              if (filters.activeCount > 0)
                TextButton(
                  onPressed: () => onChanged(const FilterState()),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                  child: const Text('Clear all', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _timePresets.entries.map((entry) {
              return ChoiceChip(
                label: Text(entry.key),
                selected: filters.timeRange == entry.value,
                onSelected: (_) => onChanged(filters.copyWith(timeRange: () => entry.value)),
                labelStyle: const TextStyle(fontSize: 11),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          if (showHttpFilter) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.http, size: 14, color: Colors.grey),
                SizedBox(width: 6),
                Text('HTTP status', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _httpRanges.map((range) {
                final isSelected = filters.httpStatusRanges.contains(range);
                return FilterChip(
                  label: Text(range),
                  selected: isSelected,
                  onSelected: (selected) {
                    final updated = Set<String>.from(filters.httpStatusRanges);
                    selected ? updated.add(range) : updated.remove(range);
                    onChanged(filters.copyWith(httpStatusRanges: updated));
                  },
                  labelStyle: const TextStyle(fontSize: 11),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
