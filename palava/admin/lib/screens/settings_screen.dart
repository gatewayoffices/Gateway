import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../api/rows.dart';
import '../widgets/common.dart';
import '../widgets/series_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.api});

  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    return Loader<(Settings, List<SeriesRow>)>(
      load: () async => (await api.getSettings(), await api.listSeries()),
      builder: (context, data, reload) =>
          _SettingsForm(api: api, settings: data.$1, series: data.$2),
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({
    required this.api,
    required this.settings,
    required this.series,
  });

  final AdminApi api;
  final Settings settings;
  final List<SeriesRow> series;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _form = GlobalKey<FormState>();
  Settings get _s => widget.settings;
  late final _free = TextEditingController(text: '${_s.freeEpisodeCount}');
  late final _cost = TextEditingController(text: '${_s.unlockCostCoins}');
  late final _ads = TextEditingController(text: '${_s.freeAdsPerDay}');
  late final _welcome = TextEditingController(text: '${_s.welcomeCoins}');
  late final _bitrate = TextEditingController(
    text: '${_s.dataSaverMaxBitrate ~/ 1000}',
  );
  late final _price = TextEditingController(text: _s.priceLabel);
  late String? _featured = _s.featuredSeriesId;
  late List<String> _forYou = [..._s.forYouSeriesIds];
  late String _paymentMode = _s.paymentMode;
  bool _saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _s
      ..freeEpisodeCount = int.parse(_free.text)
      ..unlockCostCoins = int.parse(_cost.text)
      ..freeAdsPerDay = int.parse(_ads.text)
      ..welcomeCoins = int.parse(_welcome.text)
      ..dataSaverMaxBitrate = int.parse(_bitrate.text) * 1000
      ..priceLabel = _price.text.trim()
      ..featuredSeriesId = _featured
      ..forYouSeriesIds = _forYou
      ..paymentMode = _paymentMode;
    setState(() => _saving = true);
    await runAction(
      context,
      () => widget.api.saveSettings(_s),
      done: 'Settings saved. Viewers get them the next time they open the app.',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const gap = SizedBox(height: 16, width: 16);
    Widget row(List<Widget> children) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in children) ...[Expanded(child: c), gap],
      ]..removeLast(),
    );

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const PageHeader(
            'Settings',
            subtitle:
                'App-wide defaults. A series can override free '
                'episodes and unlock cost on its own page.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Unlocking', style: text.titleLarge),
                  gap,
                  row([
                    NumberField(controller: _free, label: 'Free episodes'),
                    NumberField(
                      controller: _cost,
                      label: 'Coins to unlock an episode',
                    ),
                  ]),
                  gap,
                  row([
                    NumberField(
                      controller: _ads,
                      label: 'Free ad unlocks per day',
                    ),
                    NumberField(
                      controller: _welcome,
                      label: 'Welcome coins for new viewers',
                    ),
                  ]),
                  gap,
                  row([
                    NumberField(
                      controller: _bitrate,
                      label: 'Data saver: highest video quality (kbps)',
                      helper: 'Lower saves more data. 800 is good for phones.',
                    ),
                    TextFormField(
                      controller: _price,
                      decoration: const InputDecoration(
                        labelText: 'Price label',
                        helperText: 'Shown for prices not set per product, e.g. [PRICE]',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                  ]),
                ],
              ),
            ),
          ),
          gap,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Home and For You', style: text.titleLarge),
                  gap,
                  DropdownButtonFormField<String?>(
                    initialValue: widget.series.any((s) => s.id == _featured)
                        ? _featured
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Featured series (big banner on Home)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('First series (automatic)'),
                      ),
                      for (final s in widget.series)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            s.published ? s.title : '${s.title} (hidden)',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _featured = v),
                  ),
                  gap,
                  Text('For You feed, in order', style: text.titleMedium),
                  Text(
                    'Episode 1 of each series plays in the feed. Empty: all '
                    'series.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SeriesPicker(
                    allSeries: widget.series,
                    selected: _forYou,
                    onChanged: (ids) => setState(() => _forYou = ids),
                  ),
                ],
              ),
            ),
          ),
          gap,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Payments', style: text.titleLarge),
                  gap,
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'When a viewer taps Pay',
                      helperText:
                          'Test mode charges nothing: confirm each purchase '
                          'on the Purchases page.',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'test',
                        child: Text('Test mode (nothing is charged)'),
                      ),
                      DropdownMenuItem(
                        value: 'off',
                        child: Text('Off (payments are not open yet)'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _paymentMode = v!),
                  ),
                ],
              ),
            ),
          ),
          gap,
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save settings'),
            ),
          ),
        ],
      ),
    );
  }
}
