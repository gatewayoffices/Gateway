import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../api/rows.dart';
import '../widgets/common.dart';

/// Coin packs and passes shown in the app's Wallet.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.api});

  final AdminApi api;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  Key _key = UniqueKey();

  void _reload() => setState(() => _key = UniqueKey());

  Future<void> _editPack(CoinPackRow? pack, int nextPosition) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PackDialog(
        api: widget.api,
        pack: pack ?? CoinPackRow(coins: 100, position: nextPosition),
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _editPass(PassRow? pass, int nextPosition) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _PassDialog(api: widget.api, pass: pass, nextPosition: nextPosition),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Loader<(List<CoinPackRow>, List<PassRow>)>(
      key: _key,
      load: () async =>
          (await widget.api.listCoinPacks(), await widget.api.listPasses()),
      builder: (context, data, _) {
        final (packs, passes) = data;
        return ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const PageHeader(
              'Store',
              subtitle:
                  'What the Wallet sells. Payments are connected in '
                  'Milestone 6; until then prices are only labels.',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Coin packs', style: text.titleLarge),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _editPack(null, packs.length),
                          icon: const Icon(Icons.add),
                          label: const Text('Add pack'),
                        ),
                      ],
                    ),
                    for (final p in packs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${p.coins} coins'
                          '${p.bonusCoins > 0 ? ' + ${p.bonusCoins} bonus' : ''}',
                        ),
                        subtitle: Text(
                          '${p.priceLabel ?? 'Default price label'}'
                          '${p.active ? '' : '  ·  Hidden'}',
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editPack(p, packs.length),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Passes', style: text.titleLarge)),
                        OutlinedButton.icon(
                          onPressed: () => _editPass(null, passes.length),
                          icon: const Icon(Icons.add),
                          label: const Text('Add pass'),
                        ),
                      ],
                    ),
                    for (final p in passes)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name),
                        subtitle: Text(
                          '${p.durationHours} hours  ·  '
                          '${p.priceLabel ?? 'Default price label'}'
                          '${p.active ? '' : '  ·  Hidden'}',
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editPass(p, passes.length),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PackDialog extends StatefulWidget {
  const _PackDialog({required this.api, required this.pack});

  final AdminApi api;
  final CoinPackRow pack;

  @override
  State<_PackDialog> createState() => _PackDialogState();
}

class _PackDialogState extends State<_PackDialog> {
  final _form = GlobalKey<FormState>();
  late final _coins = TextEditingController(text: '${widget.pack.coins}');
  late final _bonus = TextEditingController(text: '${widget.pack.bonusCoins}');
  late final _price = TextEditingController(text: widget.pack.priceLabel ?? '');
  late final _position = TextEditingController(text: '${widget.pack.position}');
  late bool _active = widget.pack.active;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final p = widget.pack
      ..coins = int.parse(_coins.text)
      ..bonusCoins = int.parse(_bonus.text)
      ..priceLabel = _price.text.trim().isEmpty ? null : _price.text.trim()
      ..position = int.parse(_position.text)
      ..active = _active;
    final ok = await runAction(
      context,
      () => widget.api.saveCoinPack(p),
      done: 'Coin pack saved.',
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final sure = await confirm(
      context,
      title: 'Delete this coin pack?',
      message: 'To stop selling it for now, turn off "Shown in the app".',
    );
    if (!sure || !mounted) return;
    final ok = await runAction(
      context,
      () => widget.api.deleteCoinPack(widget.pack.id!),
      done: 'Coin pack deleted.',
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return AlertDialog(
      title: Text(widget.pack.id == null ? 'New coin pack' : 'Coin pack'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NumberField(controller: _coins, label: 'Coins'),
              gap,
              NumberField(controller: _bonus, label: 'Bonus coins'),
              gap,
              TextFormField(
                controller: _price,
                decoration: const InputDecoration(
                  labelText: 'Price label',
                  helperText: 'Empty uses the default label from Settings',
                ),
              ),
              gap,
              NumberField(
                controller: _position,
                label: 'Order',
                helper: 'Lower numbers show first',
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
      actions: [
        if (widget.pack.id != null)
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

class _PassDialog extends StatefulWidget {
  const _PassDialog({
    required this.api,
    required this.pass,
    required this.nextPosition,
  });

  final AdminApi api;
  final PassRow? pass;
  final int nextPosition;

  @override
  State<_PassDialog> createState() => _PassDialogState();
}

class _PassDialogState extends State<_PassDialog> {
  final _form = GlobalKey<FormState>();
  late final bool _isNew = widget.pass == null;
  late final _id = TextEditingController(text: widget.pass?.id ?? '');
  late final _name = TextEditingController(text: widget.pass?.name ?? '');
  late final _description = TextEditingController(
    text: widget.pass?.description ?? '',
  );
  late final _hours = TextEditingController(
    text: '${widget.pass?.durationHours ?? 24}',
  );
  late final _price = TextEditingController(
    text: widget.pass?.priceLabel ?? '',
  );
  late final _position = TextEditingController(
    text: '${widget.pass?.position ?? widget.nextPosition}',
  );
  late bool _active = widget.pass?.active ?? true;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final pass = PassRow(
      id: _id.text.trim(),
      name: _name.text.trim(),
      description: _description.text.trim(),
      durationHours: int.parse(_hours.text),
      priceLabel: _price.text.trim().isEmpty ? null : _price.text.trim(),
      position: int.parse(_position.text),
      active: _active,
    );
    final ok = await runAction(
      context,
      () => widget.api.savePass(pass),
      done: 'Pass saved.',
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final sure = await confirm(
      context,
      title: 'Delete ${widget.pass!.name}?',
      message:
          'Passes that viewers already bought cannot be deleted. To stop '
          'selling it, turn off "Shown in the app".',
    );
    if (!sure || !mounted) return;
    final ok = await runAction(
      context,
      () => widget.api.deletePass(widget.pass!.id),
      done: 'Pass deleted.',
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return AlertDialog(
      title: Text(_isNew ? 'New pass' : widget.pass!.name),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (v) {
                    if (_isNew) _id.text = SeriesRow.slugFor(v);
                  },
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                gap,
                TextFormField(
                  controller: _id,
                  enabled: _isNew,
                  decoration: const InputDecoration(
                    labelText: 'Id',
                    helperText: 'Cannot change after saving',
                  ),
                  validator: (v) =>
                      RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Use lowercase letters, numbers and dashes',
                ),
                gap,
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    helperText: 'e.g. Every episode, 24 hours',
                  ),
                ),
                gap,
                NumberField(controller: _hours, label: 'Length in hours'),
                gap,
                TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(
                    labelText: 'Price label',
                    helperText: 'Empty uses the default label from Settings',
                  ),
                ),
                gap,
                NumberField(
                  controller: _position,
                  label: 'Order',
                  helper: 'Lower numbers show first',
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
        if (!_isNew)
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
