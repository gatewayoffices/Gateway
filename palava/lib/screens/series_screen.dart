import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../widgets/common.dart';
import '../widgets/episode_grid.dart';
import '../widgets/poster_art.dart';

class SeriesScreen extends StatelessWidget {
  const SeriesScreen({super.key, required this.series});

  final Series series;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    final inMyList = state.myList.contains(series.id);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: screenWidth * 1.05,
            backgroundColor: PalavaColors.background,
            leading: const Padding(
              padding: EdgeInsets.all(4),
              child: _RoundBackButton(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: PosterArt(
                series: series,
                showTitle: false,
                borderRadius: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, PalavaColors.background],
                      stops: [0.5, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(series.title, style: textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final genre in series.genres) _MetaTag(genre),
                      _MetaTag('${series.episodeCount} episodes'),
                      _MetaTag(series.language),
                      _MetaTag(series.ageRating, highlight: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(series.synopsis, style: textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => showSampleMessage(
                      context,
                      'Episode 1 will play here once the video player is '
                      'built (Milestone 3).',
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play episode 1'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => state.toggleMyList(series.id),
                          icon: Icon(inMyList ? Icons.check : Icons.add),
                          label: const Text('My List'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showSampleMessage(
                            context,
                            state.wifiOnlyDownloads
                                ? 'Downloads arrive in Milestone 7. They will '
                                      'use WiFi only by default.'
                                : 'Downloads arrive in Milestone 7.',
                          ),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Download'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Episodes', style: textTheme.titleLarge),
                      ),
                      Text(
                        '1–${state.config.freeEpisodeCount} free',
                        style: textTheme.bodySmall?.copyWith(
                          color: PalavaColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: EpisodeGrid(series: series)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag(this.label, {this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PalavaColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? PalavaColors.gold : PalavaColors.cardBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: highlight ? PalavaColors.gold : PalavaColors.textSecondary,
        ),
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      style: IconButton.styleFrom(
        backgroundColor: PalavaColors.background.withValues(alpha: 0.6),
        minimumSize: const Size(44, 44),
      ),
      icon: const Icon(Icons.arrow_back, color: PalavaColors.text),
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}
