import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../api/rows.dart';
import '../widgets/common.dart';
import '../widgets/series_picker.dart';

/// The rows of series on the app's Home screen, e.g. "Trending in Monrovia".
class HomeRowsScreen extends StatefulWidget {
  const HomeRowsScreen({super.key, required this.api});

  final AdminApi api;

  @override
  State<HomeRowsScreen> createState() => _HomeRowsScreenState();
}

class _HomeRowsScreenState extends State<HomeRowsScreen> {
  Key _key = UniqueKey();

  Future<void> _edit(
    HomeRowRow? row,
    List<SeriesRow> series,
    int nextPosition,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _HomeRowDialog(
        api: widget.api,
        row: row ?? HomeRowRow(title: '', position: nextPosition),
        series: series,
      ),
    );
    if (saved == true) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Loader<(List<HomeRowRow>, List<SeriesRow>)>(
      key: _key,
      load: () async =>
          (await widget.api.listHomeRows(), await widget.api.listSeries()),
      builder: (context, data, _) {
        final (rows, series) = data;
        String titleOf(String id) => series
            .firstWhere(
              (s) => s.id == id,
              orElse: () => SeriesRow(id: id, title: '$id (deleted)'),
            )
            .title;
        return ListView(
          padding: const EdgeInsets.all(32),
          children: [
            PageHeader(
              'Home rows',
              subtitle:
                  'Rows appear on Home below "Continue watching", in this '
                  'order. Hidden series are skipped automatically.',
              action: FilledButton.icon(
                onPressed: () => _edit(null, series, rows.length),
                icon: const Icon(Icons.add),
                label: const Text('New row'),
              ),
            ),
            Card(
              child: Column(
                children: [
                  for (final r in rows)
                    ListTile(
                      title: Text(r.title),
                      subtitle: Text(
                        '${r.seriesIds.map(titleOf).join(', ')}'
                        '${r.active ? '' : '  ·  Hidden'}',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(r, series, rows.length),
                    ),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No rows yet.'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeRowDialog extends StatefulWidget {
  const _HomeRowDialog({
    required this.api,
    required this.row,
    required this.series,
  });

  final AdminApi api;
  final HomeRowRow row;
  final List<SeriesRow> series;

  @override
  State<_HomeRowDialog> createState() => _HomeRowDialogState();
}

class _HomeRowDialogState extends State<_HomeRowDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.row.title);
  late final _position = TextEditingController(text: '${widget.row.position}');
  late List<String> _ids = [...widget.row.seriesIds];
  late bool _active = widget.row.active;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final r = widget.row
      ..title = _title.text.trim()
      ..position = int.parse(_position.text)
      ..seriesIds = _ids
      ..active = _active;
    final ok = await runAction(
      context,
      () => widget.api.saveHomeRow(r),
      done: 'Row saved.',
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final sure = await confirm(
      context,
      title: 'Delete "${widget.row.title}"?',
      message: 'To take it off Home for now, turn off "Shown in the app".',
    );
    if (!sure || !mounted) return;
    final ok = await runAction(
      context,
      () => widget.api.deleteHomeRow(widget.row.id!),
      done: 'Row deleted.',
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return AlertDialog(
      title: Text(widget.row.id == null ? 'New row' : widget.row.title),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    helperText: 'e.g. Trending in Monrovia',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                gap,
                NumberField(
                  controller: _position,
                  label: 'Order',
                  helper: 'Lower numbers show first',
                ),
                gap,
                const Text('Series in this row, in order'),
                const SizedBox(height: 8),
                SeriesPicker(
                  allSeries: widget.series,
                  selected: _ids,
                  onChanged: (ids) => setState(() => _ids = ids),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: const Text('Shown in the app'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.row.id != null)
          TextButton(onPressed: _delete, child: const Text('Delete')),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
