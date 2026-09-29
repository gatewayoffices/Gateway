import 'package:flutter/material.dart';

import '../api/rows.dart';

/// Edits an ordered list of series: add from a menu, reorder, remove.
class SeriesPicker extends StatelessWidget {
  const SeriesPicker({
    super.key,
    required this.allSeries,
    required this.selected,
    required this.onChanged,
  });

  final List<SeriesRow> allSeries;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  String _title(String id) {
    for (final s in allSeries) {
      if (s.id == id) return s.published ? s.title : '${s.title} (hidden)';
    }
    return '$id (deleted)';
  }

  void _move(int from, int to) {
    final list = [...selected];
    list.insert(to, list.removeAt(from));
    onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    final available = [
      for (final s in allSeries)
        if (!selected.contains(s.id)) s,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < selected.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text('${i + 1}.'),
            title: Text(_title(selected[i])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Move up',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: i == 0 ? null : () => _move(i, i - 1),
                ),
                IconButton(
                  tooltip: 'Move down',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: i == selected.length - 1
                      ? null
                      : () => _move(i, i + 1),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged([...selected]..removeAt(i)),
                ),
              ],
            ),
          ),
        if (selected.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No series yet.'),
          ),
        const SizedBox(height: 8),
        if (available.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: 'Add a series',
            onSelected: (id) => onChanged([...selected, id]),
            itemBuilder: (context) => [
              for (final s in available)
                PopupMenuItem(value: s.id, child: Text(_title(s.id))),
            ],
            child: const Chip(
              avatar: Icon(Icons.add, size: 18),
              label: Text('Add a series'),
            ),
          ),
      ],
    );
  }
}
