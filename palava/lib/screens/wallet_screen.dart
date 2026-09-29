import 'package:flutter/material.dart';

import '../backend/backend.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../theme/palava_theme.dart';
import '../widgets/common.dart';

enum PaymentMethod {
  mtnMomo('mtn_momo', 'MTN Mobile Money', Icons.phone_android),
  orangeMoney('orange_money', 'Orange Money', Icons.phone_iphone),
  card('card', 'Debit or credit card', Icons.credit_card),
  appStore('app_store', 'App store', Icons.shop_outlined);

  const PaymentMethod(this.code, this.label, this.icon);

  /// Saved with the purchase.
  final String code;
  final String label;
  final IconData icon;
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  // Exactly one of these is selected: a coin pack or a pass.
  CoinPack? _pack;
  Pass? _pass;
  PaymentMethod _method = PaymentMethod.mtnMomo;
  bool _paying = false;

  bool get _hasSelection => _pack != null || _pass != null;

  @override
  void initState() {
    super.initState();
    // Picks up purchases confirmed since the wallet was last opened.
    final state = AppStateScope.read(context);
    if (state.isSignedIn) state.refreshViewer();
  }

  // The app never sees card or mobile-money details. For now payments run in
  // test mode (an admin confirms them in the admin panel); the payment
  // provider's hosted checkout plugs in here once its account exists.
  Future<void> _pay(AppState state) async {
    if (!state.canUnlock) {
      showSampleMessage(context, 'Sign in to buy coins and passes.');
      return;
    }
    if (!state.backend.isSample &&
        state.config.paymentMode == PaymentMode.off) {
      showSampleMessage(context, 'Payments are not open yet.');
      return;
    }
    final pack = _pack;
    final pass = _pass;
    setState(() => _paying = true);
    try {
      final ticket = await state.startPurchase(
        pack: pack,
        pass: pass,
        paymentMethod: _method.code,
      );
      if (!mounted) return;
      setState(() {
        _paying = false;
        _pack = null;
        _pass = null;
      });
      final product = pass?.name ?? '${pack!.coins + pack.bonusCoins} coins';
      if (state.backend.isSample) {
        showSampleMessage(
          context,
          'Sample mode: $product added. No money was charged.',
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (_) =>
              _TestPaymentDialog(product: product, reference: ticket.reference),
        );
      }
    } on BackendException catch (e) {
      if (mounted) showSampleMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final config = state.config;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: PalavaColors.ember,
                onRefresh: state.refreshViewer,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    _BalanceCard(coins: state.coinBalance),
                    if (state.hasActivePass) ...[
                      const SizedBox(height: 12),
                      _PassActiveCard(endsAt: state.passEndsAt),
                    ],
                    if (state.recentPurchases.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Recent payments', style: textTheme.titleLarge),
                      const SizedBox(height: 8),
                      for (final p in state.recentPurchases)
                        _PurchaseLine(purchase: p),
                    ],
                    const SizedBox(height: 24),
                    Text('Coin packs', style: textTheme.titleLarge),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        for (final pack in config.coinPacks)
                          _SelectableCard(
                            selected: _pack == pack,
                            onTap: () => setState(() {
                              _pack = pack;
                              _pass = null;
                            }),
                            child: _CoinPackContent(
                              pack: pack,
                              price: config.priceOf(label: pack.priceLabel),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Passes', style: textTheme.titleLarge),
                    const SizedBox(height: 12),
                    for (final pass in config.passes) ...[
                      _SelectableCard(
                        selected: _pass == pass,
                        onTap: () => setState(() {
                          _pass = pass;
                          _pack = null;
                        }),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.confirmation_number_outlined,
                              color: PalavaColors.gold,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pass.name, style: textTheme.titleMedium),
                                  Text(
                                    pass.description,
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              config.priceOf(label: pass.priceLabel),
                              style: textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 14),
                    Text('Pay with', style: textTheme.titleLarge),
                    const SizedBox(height: 12),
                    for (final method in PaymentMethod.values) ...[
                      _SelectableCard(
                        selected: _method == method,
                        onTap: () => setState(() => _method = method),
                        child: Row(
                          children: [
                            Icon(
                              method.icon,
                              color: PalavaColors.textSecondary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                method.label,
                                style: textTheme.titleMedium,
                              ),
                            ),
                            Icon(
                              _method == method
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: _method == method
                                  ? PalavaColors.ember
                                  : PalavaColors.textQuiet,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _hasSelection && !_paying
                      ? () => _pay(state)
                      : null,
                  child: _paying
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(
                          _hasSelection
                              ? 'Pay ${config.priceOf(label: _pack?.priceLabel ?? _pass?.priceLabel)}'
                              : 'Choose a pack or pass',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PalavaRadius.large),
        gradient: const LinearGradient(
          colors: [Color(0xFF3A2416), PalavaColors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: PalavaColors.cardBorder),
      ),
      child: Row(
        children: [
          const CoinIcon(size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Balance', style: Theme.of(context).textTheme.bodyMedium),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$coins coins',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPackContent extends StatelessWidget {
  const _CoinPackContent({required this.pack, required this.price});

  final CoinPack pack;
  final String price;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const CoinIcon(size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatCoins(pack.coins),
                  style: textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
        if (pack.bonusCoins > 0)
          Text(
            '+${pack.bonusCoins} bonus',
            style: const TextStyle(
              color: PalavaColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        Text(price, style: textTheme.titleMedium),
      ],
    );
  }

  static String _formatCoins(int coins) {
    final text = coins.toString();
    if (text.length <= 3) return text;
    return '${text.substring(0, text.length - 3)},'
        '${text.substring(text.length - 3)}';
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? PalavaColors.ember.withValues(alpha: 0.12)
          : PalavaColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PalavaRadius.medium),
        side: BorderSide(
          color: selected ? PalavaColors.ember : PalavaColors.cardBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(PalavaRadius.medium),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}

/// Shown after starting a payment while payments are in test mode.
class _TestPaymentDialog extends StatelessWidget {
  const _TestPaymentDialog({required this.product, required this.reference});

  final String product;
  final String reference;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Test payment started'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payments are in test mode, so nothing is charged. Your $product '
            'will arrive once the payment is confirmed.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text('Reference', style: textTheme.bodySmall),
          SelectableText(reference, style: textTheme.titleLarge),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _PassActiveCard extends StatelessWidget {
  const _PassActiveCard({required this.endsAt});

  final DateTime? endsAt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PalavaColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PalavaRadius.medium),
        border: Border.all(color: PalavaColors.gold),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            color: PalavaColors.gold,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pass active', style: textTheme.titleMedium),
                Text(
                  endsAt == null
                      ? 'Every episode is unlocked.'
                      : 'Every episode is unlocked until '
                            '${formatDateTime(endsAt!)}.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseLine extends StatelessWidget {
  const _PurchaseLine({required this.purchase});

  final PurchaseSummary purchase;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (label, color) = switch (purchase.status) {
      PurchaseStatus.pending => ('Waiting', PalavaColors.gold),
      PurchaseStatus.paid => ('Paid', PalavaColors.textSecondary),
      PurchaseStatus.failed => ('Cancelled', PalavaColors.textQuiet),
      PurchaseStatus.refunded => ('Refunded', PalavaColors.textQuiet),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(purchase.productName, style: textTheme.titleMedium),
                Text(
                  '${purchase.reference}  ·  '
                  '${formatDateTime(purchase.createdAt)}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(label, style: textTheme.labelLarge?.copyWith(color: color)),
        ],
      ),
    );
  }
}
