import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../theme/palava_theme.dart';
import '../widgets/common.dart';

enum PaymentMethod {
  mtnMomo('MTN Mobile Money', Icons.phone_android),
  orangeMoney('Orange Money', Icons.phone_iphone),
  card('Debit or credit card', Icons.credit_card),
  appStore('App store', Icons.shop_outlined);

  const PaymentMethod(this.label, this.icon);

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

  bool get _hasSelection => _pack != null || _pass != null;

  void _pay(AppState state) {
    // Sample only. Real payments open the provider's hosted checkout
    // (Flutterwave/Paystack or RevenueCat) in Milestone 6; the app never
    // sees card or mobile-money details.
    final pack = _pack;
    if (!state.backend.isSample) {
      showSampleMessage(
        context,
        'Payments are connected in Milestone 6. Nothing was charged.',
      );
    } else if (pack != null) {
      state.addSampleCoins(pack.coins + pack.bonusCoins);
      showSampleMessage(
        context,
        'Sample mode: added ${pack.coins + pack.bonusCoins} coins. '
        'No money was charged.',
      );
    } else {
      showSampleMessage(
        context,
        'Sample mode: passes will work once payments are connected.',
      );
    }
    setState(() {
      _pack = null;
      _pass = null;
    });
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  _BalanceCard(coins: state.coinBalance),
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
                          Icon(method.icon, color: PalavaColors.textSecondary),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _hasSelection ? () => _pay(state) : null,
                  child: Text(
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
