import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../widgets/common.dart';
import 'wallet_screen.dart';

/// Shows the unlock sheet for a locked episode. Returns true if the viewer
/// unlocked it.
Future<bool> showUnlockSheet(
  BuildContext context, {
  required Series series,
  required int episodeNumber,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => UnlockSheet(series: series, episodeNumber: episodeNumber),
  );
  return result ?? false;
}

class UnlockSheet extends StatelessWidget {
  const UnlockSheet({
    super.key,
    required this.series,
    required this.episodeNumber,
  });

  final Series series;
  final int episodeNumber;

  void _openWallet(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop(false);
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
    );
  }

  void _unlockWithCoins(BuildContext context, AppState state) {
    if (state.unlockWithCoins(series.id, episodeNumber)) {
      Navigator.of(context).pop(true);
    }
  }

  void _watchAd(BuildContext context, AppState state) {
    // Sample only: real rewarded ads come from AdMob in Milestone 6.
    if (state.unlockWithAd(series.id, episodeNumber)) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final config = state.config;
    final textTheme = Theme.of(context).textTheme;
    final canAfford = state.coinBalance >= config.unlockCostCoins;
    final dayPass = config.passes.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.lock, color: PalavaColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Episode $episodeNumber is locked',
                  style: textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Keep watching ${series.title}. The first '
            '${config.freeEpisodeCount} episodes are free.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PalavaColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PalavaColors.cardBorder),
            ),
            child: Row(
              children: [
                const CoinIcon(size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your balance', style: textTheme.bodySmall),
                      Text(
                        '${state.coinBalance} coins',
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _openWallet(context),
                  child: const Text('Top up'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canAfford
                ? () => _unlockWithCoins(context, state)
                : () => _openWallet(context),
            child: Text(
              canAfford
                  ? 'Unlock with ${config.unlockCostCoins} coins'
                  : 'Get coins to unlock',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _openWallet(context),
            child: Text('${dayPass.name}  ·  ${config.priceLabel}'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: state.adsLeftToday > 0
                ? () => _watchAd(context, state)
                : null,
            icon: const Icon(Icons.smart_display_outlined),
            label: Text(
              state.adsLeftToday > 0
                  ? 'Watch a short ad (free, ${state.adsLeftToday} left today)'
                  : 'No free ads left today',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.autoUnlock,
            onChanged: state.setAutoUnlock,
            title: const Text('Auto-unlock next episodes'),
            subtitle: Text(
              'Use coins automatically so the story keeps playing.',
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
