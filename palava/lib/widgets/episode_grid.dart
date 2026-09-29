import 'package:flutter/material.dart';

import '../data/models.dart';
import '../screens/unlock_sheet.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../theme/palava_theme.dart';
import 'common.dart';

/// Grid of episode numbers. Free or unlocked episodes play; locked ones open
/// the unlock sheet.
class EpisodeGrid extends StatelessWidget {
  const EpisodeGrid({
    super.key,
    required this.series,
    this.shrinkWrap = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Series series;
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
    showSampleMessage(
      context,
      'Episode $episode will play here once the video player is built '
      '(Milestone 3).',
    );
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
        return Material(
          color: PalavaColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PalavaRadius.small),
            side: const BorderSide(color: PalavaColors.cardBorder),
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
