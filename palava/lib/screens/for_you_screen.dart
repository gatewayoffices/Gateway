import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../playback/episode_feed.dart';
import '../playback/episode_view.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../theme/palava_theme.dart';
import '../widgets/common.dart';
import '../widgets/episode_grid.dart';
import '../widgets/poster_art.dart';
import 'player_screen.dart';
import 'series_screen.dart';

/// Full-screen vertical feed of first episodes. Swipe up for the next series.
class ForYouScreen extends StatefulWidget {
  const ForYouScreen({super.key, required this.isActive});

  /// Whether this tab is on screen. Nothing plays or loads while it is not.
  final bool isActive;

  @override
  State<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<ForYouScreen> {
  final _feed = EpisodeFeedController();
  final _series = SampleData.forYouSeriesIds
      .map(SampleData.seriesById)
      .toList();
  late final _episodes = [
    for (final series in _series) SampleData.episodesFor(series).first,
  ];

  @override
  Widget build(BuildContext context) {
    final showSubtitles = AppStateScope.of(context).subtitles;
    return EpisodeFeed(
      controller: _feed,
      episodes: _episodes,
      active: widget.isActive,
      itemBuilder: (context, index, player) => _FeedPage(
        series: _series[index],
        episode: _episodes[index],
        player: player,
        showSubtitles: showSubtitles,
        onRetry: () => _feed.retry(index),
      ),
    );
  }
}

class _FeedPage extends StatelessWidget {
  const _FeedPage({
    required this.series,
    required this.episode,
    required this.player,
    required this.showSubtitles,
    required this.onRetry,
  });

  final Series series;
  final Episode episode;
  final VideoPlayerController? player;
  final bool showSubtitles;
  final VoidCallback onRetry;

  void _showEpisodes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                series.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            EpisodeGrid(
              series: series,
              onPlay: (number) {
                Navigator.of(sheetContext).pop();
                openPlayer(context, series, episode: number);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _watchAll(BuildContext context) {
    // Carry on from the same moment in the full player.
    final position = player?.value.position;
    openPlayer(context, series, episode: 1, position: position);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    final liked = state.liked.contains(series.id);
    final inMyList = state.myList.contains(series.id);

    return Stack(
      fit: StackFit.expand,
      children: [
        EpisodeVideo(
          controller: player,
          showSubtitles: showSubtitles,
          onRetry: onRetry,
          placeholder: PosterArt(
            series: series,
            showTitle: false,
            borderRadius: 0,
          ),
          subtitleBottomPadding: 230,
        ),
        // Darken the bottom so text stays readable over any video.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xD91A120D)],
                stops: [0.5, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'For You',
                  style: TextStyle(
                    fontFamily: PalavaFonts.title,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: PalavaColors.text,
                  ),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SeriesScreen(series: series),
                              ),
                            ),
                            child: Text(
                              series.title,
                              style: textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Episode 1 of ${series.episodeCount}  ·  '
                            '${series.tagline}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            onPressed: () => _watchAll(context),
                            icon: const Icon(Icons.video_library_outlined),
                            label: const Text('Watch all episodes'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SideAction(
                          icon: liked ? Icons.favorite : Icons.favorite_border,
                          color: liked ? PalavaColors.ember : null,
                          label: 'Like',
                          onTap: () => state.toggleLike(series.id),
                        ),
                        _SideAction(
                          icon: inMyList ? Icons.bookmark : Icons.bookmark_add,
                          color: inMyList ? PalavaColors.gold : null,
                          label: 'My List',
                          onTap: () => state.toggleMyList(series.id),
                        ),
                        _SideAction(
                          icon: Icons.grid_view_rounded,
                          label: 'Episodes',
                          onTap: () => _showEpisodes(context),
                        ),
                        _SideAction(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: () => showSampleMessage(
                            context,
                            'Sharing will be added in a later milestone.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: player == null
                      ? ProgressLine(
                          value: 0,
                          height: 3,
                          trackColor: PalavaColors.text.withValues(alpha: 0.2),
                        )
                      : EpisodeProgressBar(
                          controller: player!,
                          endsAt: episode.endsAt,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(PalavaRadius.small),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 64)
            .copyWith(minHeight: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 6),
            Icon(icon, size: 30, color: color ?? PalavaColors.text),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: PalavaColors.text,
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
