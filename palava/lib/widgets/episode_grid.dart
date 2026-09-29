import 'package:flutter/material.dart';

import '../data/models.dart';
import '../screens/unlock_sheet.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../theme/palava_theme.dart';

/// Grid of episode numbers. Free or unlocked episodes play; locked ones open
/// the unlock sheet.
class EpisodeGrid extends StatelessWidget {
  const EpisodeGrid({
    super.key,
    required this.series,
    required this.onPlay,
    this.currentEpisode,
    this.shrinkWrap = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Series series;

  /// Called with the episode number once it is free or unlocked.
  final ValueChanged<int> onPlay;

  /// Episode to highlight (the one playing), if any.
  final int? currentEpisode;
  final bool shrinkWrap;
  final EdgeInsets padding;

  Future<void> _onTap(BuildContext context, int episode, bool unlocked) async {
    if (!unlocked) {
      final didUnlock = await showUnlockSheet(
        context,
        series: series,
        episodeNumber: episode,
      );
      if (!didUnlock || !context.mounted) return;
    }
    onPlay(episode);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: padding,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 72,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: series.episodeCount,
      itemBuilder: (context, i) {
        final episode = i + 1;
        final unlocked = state.isUnlocked(series.id, episode);
        final isCurrent = episode == currentEpisode;
        return Material(
          color: isCurrent
              ? PalavaColors.ember.withValues(alpha: 0.18)
              : PalavaColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PalavaRadius.small),
            side: BorderSide(
              color: isCurrent ? PalavaColors.ember : PalavaColors.cardBorder,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(PalavaRadius.small),
            onTap: () => _onTap(context, episode, unlocked),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '$episode',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: unlocked
                          ? PalavaColors.text
                          : PalavaColors.textQuiet,
                    ),
                  ),
                ),
                if (!unlocked)
                  const Positioned(
                    right: 6,
                    top: 6,
                    child: Icon(Icons.lock, size: 14, color: PalavaColors.gold),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
