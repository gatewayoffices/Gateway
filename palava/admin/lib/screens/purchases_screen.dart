import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../api/rows.dart';
import '../widgets/common.dart';

/// Viewers' purchases. In test mode, confirm one here to give the viewer the
/// coins or pass; nothing is charged.
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key, required this.api});

  final AdminApi api;

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  Key _key = UniqueKey();

  void _reload() => setState(() => _key = UniqueKey());

  Future<void> _confirm(PurchaseRow p) async {
    final ok = await runAction(
      context,
      () => widget.api.confirmPurchase(p.id),
      done: '${p.reference} confirmed. ${p.viewer} now has ${p.productName}.',
    );
    if (ok) _reload();
  }

  Future<void> _cancel(PurchaseRow p) async {
    final sure = await confirm(
      context,
      title: 'Cancel ${p.reference}?',
      message: 'The viewer does not get ${p.productName}.',
      action: 'Cancel purchase',
    );
    if (!sure || !mounted) return;
    final ok = await runAction(
      context,
      () => widget.api.cancelPurchase(p.id),
      done: '${p.reference} cancelled.',
    );
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<PurchaseRow>>(
      key: _key,
      load: widget.api.listPurchases,
      builder: (context, purchases, _) => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          PageHeader(
            'Purchases',
            subtitle:
                'Test mode: nothing is charged. Confirm a purchase to give '
                'the viewer what they chose. Unfinished ones are at the top.',
            action: OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (purchases.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No purchases yet.'),
                    ),
                  for (final p in purchases)
                    _PurchaseTile(
                      purchase: p,
                      onConfirm: () => _confirm(p),
                      onCancel: () => _cancel(p),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({
    required this.purchase,
    required this.onConfirm,
    required this.onCancel,
  });

  final PurchaseRow purchase;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  static const _methods = {
    'mtn_momo': 'MTN Mobile Money',
    'orange_money': 'Orange Money',
    'card': 'Card',
    'app_store': 'App store',
  };

  @override
  Widget build(BuildContext context) {
    final p = purchase;
    final text = Theme.of(context).textTheme;
    final (label, color) = switch (p.status) {
      'pending' => ('Waiting', gold),
      'paid' => ('Paid', Colors.green.shade300),
      'failed' => ('Cancelled', Colors.grey),
      _ => (p.status, Colors.grey),
    };
    final when = p.createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${p.productName}  ·  ${p.viewer}'),
      subtitle: Text(
        [
          p.reference,
          '${when.year}-${two(when.month)}-${two(when.day)} '
              '${two(when.hour)}:${two(when.minute)}',
          ?_methods[p.paymentMethod],
          ?p.priceLabel,
          if (p.provider != 'test') p.provider,
        ].join('  ·  '),
        style: text.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: text.labelLarge?.copyWith(color: color)),
          if (p.canConfirm) ...[
            const SizedBox(width: 16),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(onPressed: onConfirm, child: const Text('Confirm')),
          ],
        ],
      ),
    );
  }
}
