import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../api/rows.dart';
import '../widgets/common.dart';
import 'episode_dialogs.dart';

/// Create a series (when [series] is null) or edit one and its episodes.
class SeriesEditorScreen extends StatefulWidget {
  const SeriesEditorScreen({super.key, required this.api, this.series});

  final AdminApi api;
  final SeriesRow? series;

  @override
  State<SeriesEditorScreen> createState() => _SeriesEditorScreenState();
}

class _SeriesEditorScreenState extends State<SeriesEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final SeriesRow _series = widget.series ?? SeriesRow(id: '', title: '');
  late bool _isNew = widget.series == null;
  bool _idEdited = false;
  bool _saving = false;

  late final _id = TextEditingController(text: _series.id);
  late final _title = TextEditingController(text: _series.title);
  late final _tagline = TextEditingController(text: _series.tagline);
  late final _synopsis = TextEditingController(text: _series.synopsis);
  late final _genres = TextEditingController(text: _series.genres.join(', '));
  late final _language = TextEditingController(text: _series.language);
  late final _ageRating = TextEditingController(text: _series.ageRating);
  late final _color1 = TextEditingController(
    text: _series.posterColors.isNotEmpty ? _series.posterColors[0] : '',
  );
  late final _color2 = TextEditingController(
    text: _series.posterColors.length > 1 ? _series.posterColors[1] : '',
  );
  late final _freeEpisodes = TextEditingController(
    text: _series.freeEpisodeCount?.toString() ?? '',
  );
  late final _unlockCost = TextEditingController(
    text: _series.unlockCostCoins?.toString() ?? '',
  );
  late bool _published = _series.published;

  Key _episodesKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _title.addListener(() {
      if (_isNew && !_idEdited) _id.text = SeriesRow.slugFor(_title.text);
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _series
      ..id = _id.text.trim()
      ..title = _title.text.trim()
      ..tagline = _tagline.text.trim()
      ..synopsis = _synopsis.text.trim()
      ..genres = [
        for (final g in _genres.text.split(','))
          if (g.trim().isNotEmpty) g.trim(),
      ]
      ..language = _language.text.trim()
      ..ageRating = _ageRating.text.trim()
      ..posterColors = [_color1.text.trim(), _color2.text.trim()]
      ..freeEpisodeCount = parseOptional(_freeEpisodes)
      ..unlockCostCoins = parseOptional(_unlockCost)
      ..published = _published;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => _isNew
          ? widget.api.createSeries(_series)
          : widget.api.updateSeries(_series),
      done: 'Saved. Viewers see changes the next time they open the app.',
    );
    if (mounted) {
      setState(() {
        _saving = false;
        if (ok) _isNew = false;
      });
    }
  }

  Future<void> _delete() async {
    final sure = await confirm(
      context,
      title: 'Delete ${_series.title}?',
      message:
          'This deletes the series and all its episodes for everyone. '
          'Viewers lose their unlocks and history for it. This cannot be '
          'undone. To take it out of the app for now, set it to hidden '
          'instead.',
    );
    if (!sure || !mounted) return;
    final ok = await runAction(
      context,
      () => widget.api.deleteSeries(_series.id),
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  String? _hex(String? v) =>
      RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v?.trim() ?? '')
      ? null
      : 'Like #8C2F1B';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New series' : _series.title),
        actions: [
          if (!_isNew)
            TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete series'),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _details(text),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isNew)
                      const Text(
                        'Save the series first, then add its episodes here.',
                      )
                    else
                      EpisodesSection(
                        key: _episodesKey,
                        api: widget.api,
                        series: _series,
                        onChanged: () =>
                            setState(() => _episodesKey = UniqueKey()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(TextTheme text) {
    const gap = SizedBox(height: 16, width: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Details', style: text.titleLarge),
        gap,
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
        ),
        gap,
        TextFormField(
          controller: _id,
          enabled: _isNew,
          onChanged: (_) => _idEdited = true,
          decoration: const InputDecoration(
            labelText: 'Id',
            helperText:
                'Lowercase letters, numbers and dashes. Cannot change '
                'after saving.',
          ),
          validator: (v) =>
              RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(v?.trim() ?? '')
              ? null
              : 'Use lowercase letters, numbers and dashes',
        ),
        gap,
        TextFormField(
          controller: _tagline,
          decoration: const InputDecoration(
            labelText: 'Tagline',
            helperText: 'One short line, shown on Home and in For You.',
          ),
        ),
        gap,
        TextFormField(
          controller: _synopsis,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Synopsis'),
        ),
        gap,
        TextFormField(
          controller: _genres,
          decoration: const InputDecoration(
            labelText: 'Genres',
            helperText: 'Separate with commas, e.g. Romance, Family',
          ),
        ),
        gap,
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _language,
                decoration: const InputDecoration(labelText: 'Language'),
              ),
            ),
            gap,
            Expanded(
              child: TextFormField(
                controller: _ageRating,
                decoration: const InputDecoration(labelText: 'Age rating'),
              ),
            ),
          ],
        ),
        gap,
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _color1,
                decoration: const InputDecoration(
                  labelText: 'Poster colour 1',
                  helperText: 'Placeholder poster until artwork exists',
                ),
                validator: _hex,
              ),
            ),
            gap,
            Expanded(
              child: TextFormField(
                controller: _color2,
                decoration: const InputDecoration(labelText: 'Poster colour 2'),
                validator: _hex,
              ),
            ),
          ],
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: NumberField(
                controller: _freeEpisodes,
                label: 'Free episodes',
                helper: 'Leave empty to use the app setting',
                optional: true,
              ),
            ),
            gap,
            Expanded(
              child: NumberField(
                controller: _unlockCost,
                label: 'Coins to unlock an episode',
                helper: 'Leave empty to use the app setting',
                optional: true,
              ),
            ),
          ],
        ),
        gap,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _published,
          onChanged: (v) => setState(() => _published = v),
          title: const Text('Published'),
          subtitle: const Text(
            'Off: hidden from viewers while you prepare it.',
          ),
        ),
        gap,
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_isNew ? 'Create series' : 'Save changes'),
          ),
        ),
      ],
    );
  }
}
