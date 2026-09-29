import 'package:flutter/material.dart';

import '../ads/rewarded_ads.dart';
import '../backend/backend.dart';
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

class UnlockSheet extends StatefulWidget {
  const UnlockSheet({
    super.key,
    required this.series,
    required this.episodeNumber,
  });

  final Series series;
  final int episodeNumber;

  @override
  State<UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends State<UnlockSheet> {
  bool _busy = false;
  String? _error;

  Series get series => widget.series;
  int get episodeNumber => widget.episodeNumber;

  void _openWallet(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop(false);
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
    );
  }

  /// [unlock] returns null when done, or a sentence explaining why not.
  Future<void> _run(Future<String?> Function() unlock) async {
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final problem = await unlock();
      if (problem == null) {
        navigator.pop(true);
      } else if (mounted) {
        setState(() => _error = problem);
      }
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _signIn(BuildContext context, AppState state) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    state.leaveGuestMode();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final config = state.config;
    final textTheme = Theme.of(context).textTheme;
    final cost = config.unlockCostFor(series);
    final canAfford = state.coinBalance >= cost;
    final dayPass = config.passes.isEmpty ? null : config.passes.first;

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
            '${config.freeEpisodesFor(series)} episodes are free.',
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
          if (_error != null) ...[
            Text(
              _error!,
              style: textTheme.bodyMedium?.copyWith(color: PalavaColors.ember),
            ),
            const SizedBox(height: 12),
          ],
          if (!state.canUnlock) ...[
            FilledButton(
              onPressed: () => _signIn(context, state),
              child: const Text('Sign in to unlock'),
            ),
            const SizedBox(height: 8),
            Text(
              'Coins and unlocked episodes are saved to your account.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ] else ...[
            FilledButton(
              onPressed: _busy
                  ? null
                  : canAfford
                  ? () => _run(() async {
                      await state.unlockWithCoins(series, episodeNumber);
                      return null;
                    })
                  : () => _openWallet(context),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      canAfford
                          ? 'Unlock with $cost coins'
                          : 'Get coins to unlock',
                    ),
            ),
            if (dayPass != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _openWallet(context),
                child: Text(
                  '${dayPass.name}  ·  ${config.priceOf(label: dayPass.priceLabel)}',
                ),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: state.adsLeftToday > 0 && !_busy
                  ? () => _run(() async {
                      final outcome = await state.unlockWithAd(
                        series,
                        episodeNumber,
                      );
                      return switch (outcome) {
                        AdOutcome.rewarded => null,
                        AdOutcome.skipped =>
                          'Watch the whole ad to unlock the episode.',
                        AdOutcome.unavailable =>
                          'No ad is available right now. Try again later.',
                      };
                    })
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
        ],
      ),
    );
  }
}
