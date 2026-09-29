import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../api/rows.dart';
import '../widgets/common.dart';
import 'series_editor_screen.dart';

class SeriesListScreen extends StatefulWidget {
  const SeriesListScreen({super.key, required this.api});

  final AdminApi api;

  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  Key _loaderKey = UniqueKey();

  Future<void> _open(SeriesRow? series) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeriesEditorScreen(api: widget.api, series: series),
      ),
    );
    // Reload: counts or publish state may have changed.
    setState(() => _loaderKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<SeriesRow>>(
      key: _loaderKey,
      load: widget.api.listSeries,
      builder: (context, series, reload) => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          PageHeader(
            'Series',
            subtitle:
                'Hidden series are only visible here. Publish one to show '
                'it in the app.',
            action: FilledButton.icon(
              onPressed: () => _open(null),
              icon: const Icon(Icons.add),
              label: const Text('New series'),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final s in series) ...[
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          colors: [
                            for (final hex in s.posterColors.take(2))
                              _colorFrom(hex),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                      ),
                    ),
                    title: Text(s.title),
                    subtitle: Text(
                      '${s.episodeCount} episodes  ·  ${s.genres.join(', ')}',
                    ),
                    trailing: Chip(
                      label: Text(s.published ? 'Published' : 'Hidden'),
                      backgroundColor: s.published
                          ? Colors.green.shade900
                          : null,
                    ),
                    onTap: () => _open(s),
                  ),
                  if (s != series.last) const Divider(height: 1),
                ],
                if (series.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No series yet. Click "New series".'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _colorFrom(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null ? Colors.brown : Color(0xFF000000 | value);
}
