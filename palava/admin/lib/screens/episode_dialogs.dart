import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../api/rows.dart';
import '../widgets/common.dart';

/// The episode list on a series page.
class EpisodesSection extends StatelessWidget {
  const EpisodesSection({
    super.key,
    required this.api,
    required this.series,
    required this.onChanged,
  });

  final AdminApi api;
  final SeriesRow series;

  /// Called after anything is saved, to reload the list.
  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context, EpisodeRow episode) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EpisodeDialog(api: api, episode: episode),
    );
    if (saved == true) onChanged();
  }

  Future<void> _addMany(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AddEpisodesDialog(api: api, seriesId: series.id),
    );
    if (saved == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Loader<List<EpisodeRow>>(
      load: () => api.listEpisodes(series.id),
      builder: (context, episodes, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Episodes (${episodes.length})',
                      style: text.titleLarge,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _addMany(context),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Add episodes'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${series.freeEpisodeCount == null ? 'The number of free '
                          'episodes comes from Settings.' : 'Episodes 1 to '
                          '${series.freeEpisodeCount} are free.'} '
                'An episode without a video link cannot be played.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final e in episodes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${e.number}')),
                  title: Text(e.title ?? 'Episode ${e.number}'),
                  subtitle: Text(
                    [
                      if (e.durationSeconds != null)
                        '${e.durationSeconds} seconds',
                      e.videoUrl == null ? 'No video link' : 'Video linked',
                      if (e.subtitlesVtt != null) 'Subtitles',
                      if (!e.published) 'Hidden',
                    ].join('  ·  '),
                    style: TextStyle(color: e.videoUrl == null ? gold : null),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _edit(context, e),
                ),
              if (episodes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No episodes yet. Click "Add episodes".'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit one episode: title, length, video link, subtitles, hidden or not.
class EpisodeDialog extends StatefulWidget {
  const EpisodeDialog({super.key, required this.api, required this.episode});

  final AdminApi api;
  final EpisodeRow episode;

  @override
  State<EpisodeDialog> createState() => _EpisodeDialogState();
}

class _EpisodeDialogState extends State<EpisodeDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.episode.title ?? '');
  late final _duration = TextEditingController(
    text: widget.episode.durationSeconds?.toString() ?? '',
  );
  late final _url = TextEditingController(text: widget.episode.videoUrl ?? '');
  late final _subtitles = TextEditingController(
    text: widget.episode.subtitlesVtt ?? '',
  );
  late bool _published = widget.episode.published;
  bool _saving = false;

  Future<void> _loadSubtitles() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['vtt'],
    );
    if (file == null) return;
    final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    if (!text.trimLeft().startsWith('WEBVTT')) {
      if (mounted) {
        showMessage(
          context,
          'That file is not a WebVTT (.vtt) subtitle file.',
          error: true,
        );
      }
      return;
    }
    setState(() => _subtitles.text = text);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final e = widget.episode
      ..title = _title.text.trim().isEmpty ? null : _title.text.trim()
      ..durationSeconds = parseOptional(_duration)
      ..videoUrl = _url.text.trim()
      ..subtitlesVtt = _subtitles.text
      ..published = _published;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => widget.api.saveEpisode(e),
      done: 'Episode ${e.number} saved.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final sure = await confirm(
      context,
      title: 'Delete episode ${widget.episode.number}?',
      message:
          'Viewers who unlocked it lose that unlock. Episode numbers after '
          'it do not change. To take it out of the app for now, turn off '
          '"Published" instead.',
    );
    if (!sure || !mounted) return;
    final ok = await runAction(
      context,
      () => widget.api.deleteEpisode(widget.episode),
      done: 'Episode deleted.',
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return AlertDialog(
      title: Text('Episode ${widget.episode.number}'),
      content: SizedBox(
        width: 620,
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
                    labelText: 'Title (optional)',
                  ),
                ),
                gap,
                TextFormField(
                  controller: _url,
                  decoration: const InputDecoration(
                    labelText: 'Video link (.m3u8)',
                    helperText:
                        'The HLS link from the video host. Leave empty if '
                        'the video is not ready.',
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return null;
                    final uri = Uri.tryParse(value);
                    return uri != null && uri.scheme == 'https'
                        ? null
                        : 'Must start with https://';
                  },
                ),
                gap,
                NumberField(
                  controller: _duration,
                  label: 'Length in seconds',
                  helper: 'The app treats the episode as finished here.',
                  optional: true,
                ),
                gap,
                Row(
                  children: [
                    const Expanded(child: Text('Subtitles (WebVTT)')),
                    TextButton.icon(
                      onPressed: _loadSubtitles,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Load .vtt file'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _subtitles.clear()),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _subtitles,
                  minLines: 4,
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'WEBVTT\n\n00:00:01.000 --> 00:00:04.000\n...',
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    return value.isEmpty || value.startsWith('WEBVTT')
                        ? null
                        : 'Subtitles must start with WEBVTT';
                  },
                ),
                gap,
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _published,
                  onChanged: (v) => setState(() => _published = v),
                  title: const Text('Published'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.episode.id != null)
          TextButton(onPressed: _delete, child: const Text('Delete')),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Adds several episodes at once, numbered after the last one.
class AddEpisodesDialog extends StatefulWidget {
  const AddEpisodesDialog({
    super.key,
    required this.api,
    required this.seriesId,
  });

  final AdminApi api;
  final String seriesId;

  @override
  State<AddEpisodesDialog> createState() => _AddEpisodesDialogState();
}

class _AddEpisodesDialogState extends State<AddEpisodesDialog> {
  final _form = GlobalKey<FormState>();
  final _count = TextEditingController(text: '1');
  final _duration = TextEditingController();
  final _url = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final count = int.parse(_count.text);
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => widget.api.addEpisodes(
        widget.seriesId,
        count: count,
        videoUrl: _url.text,
        durationSeconds: parseOptional(_duration),
      ),
      done: 'Added $count episode${count == 1 ? '' : 's'}.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return AlertDialog(
      title: const Text('Add episodes'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New episodes are numbered after the last one. You can set '
                'each episode\'s own video and subtitles afterwards.',
              ),
              gap,
              TextFormField(
                controller: _count,
                decoration: const InputDecoration(labelText: 'How many'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 1 || n > 200
                      ? 'Between 1 and 200'
                      : null;
                },
              ),
              gap,
              NumberField(
                controller: _duration,
                label: 'Length in seconds (optional)',
                optional: true,
              ),
              gap,
              TextFormField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Video link for all of them (optional)',
                  helperText: 'Handy for testing with one sample stream.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
