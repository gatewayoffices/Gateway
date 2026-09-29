import 'package:flutter/material.dart';

import '../data/models.dart';
import '../backend/backend.dart';
import '../playback/episode_feed.dart';
import '../playback/episode_view.dart';
import '../playback/watch_history.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../widgets/common.dart';
import '../widgets/episode_grid.dart';
import '../widgets/poster_art.dart';
import 'unlock_sheet.dart';

/// Opens the player. Without [episode], resumes where the viewer left off.
void openPlayer(
  BuildContext context,
  Series series, {
  int? episode,
  Duration? position,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(
        series: series,
        startEpisode: episode,
        startPosition: position,
      ),
    ),
  );
}

/// Full-screen vertical player for one series: swipe up for the next episode.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.series,
    this.startEpisode,
    this.startPosition,
  });

  final Series series;
  final int? startEpisode;
  final Duration? startPosition;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _feed = EpisodeFeedController();
  late final int _count;
  late final int _startIndex;
  Duration? _startPosition;
  late int _index;

  /// Kept from initState: progress is also saved while the screen closes,
  /// when looking it up through context is no longer allowed.
  late final AppState _state;

  Series get _series => widget.series;

  @override
  void initState() {
    super.initState();
    _state = AppStateScope.read(context);
    _count = _series.episodeCount;
    final requested = widget.startEpisode;
    if (requested != null) {
      _startIndex = (requested - 1).clamp(0, _count - 1);
      _startPosition = widget.startPosition;
    } else {
      final last = _state.history.lastFor(_series.id);
      if (last == null) {
        _startIndex = 0;
      } else if (last.isFinished && last.episodeNumber < _count) {
        _startIndex = last.episodeNumber; // the next episode
      } else {
        _startIndex = last.episodeNumber - 1;
        _startPosition = last.isFinished ? null : last.position;
      }
    }
    _index = _startIndex;
  }

  bool _isLocked(int index) => !_state.isUnlocked(_series, index + 1);

  Future<void> _onLocked(int index) async {
    final state = _state;
    final episode = index + 1;
    final cost = state.config.unlockCostFor(_series);
    if (state.autoUnlock && state.canUnlock && state.coinBalance >= cost) {
      try {
        await state.unlockWithCoins(_series, episode);
        if (mounted) {
          showSampleMessage(
            context,
            'Unlocked episode $episode for $cost coins.',
          );
        }
        return;
      } on BackendException {
        // Fall through to the sheet, which explains what went wrong.
      }
    }
    if (!mounted) return;
    await showUnlockSheet(context, series: _series, episodeNumber: episode);
  }

  void _onProgress(
    int index,
    Duration position,
    Duration length, {
    required bool leaving,
  }) {
    _state.recordProgress(
      WatchEntry(
        seriesId: _series.id,
        episodeNumber: index + 1,
        position: position,
        duration: length,
        updatedAt: DateTime.now(),
      ),
      refreshScreens: leaving,
    );
  }

  void _showEpisodes() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                _series.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            EpisodeGrid(
              series: _series,
              currentEpisode: _index + 1,
              onPlay: (episode) {
                Navigator.of(sheetContext).pop();
                _feed.jumpTo(episode - 1);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          EpisodeFeed(
            controller: _feed,
            itemCount: _count,
            loadEpisode: (i) => _state.backend.loadEpisode(_series, i + 1),
            initialIndex: _startIndex,
            initialPosition: _startPosition,
            isLocked: _isLocked,
            onLocked: _onLocked,
            onIndexChanged: (i) => setState(() => _index = i),
            onProgress: _onProgress,
            onFinishedLast: () =>
                showSampleMessage(context, 'That is the last episode for now.'),
            itemBuilder: (context, index, item) => _EpisodePage(
              series: _series,
              number: index + 1,
              item: item,
              locked: _isLocked(index),
              showSubtitles: state.subtitles,
              onRetry: () => _feed.retry(index),
              onUnlock: () async {
                final unlocked = await showUnlockSheet(
                  context,
                  series: _series,
                  episodeNumber: index + 1,
                );
                if (unlocked) _feed.refreshCurrent();
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    iconSize: 28,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _series.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Episode ${_index + 1} of $_count',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: PalavaColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: state.subtitles
                        ? 'Turn subtitles off'
                        : 'Turn subtitles on',
                    iconSize: 28,
                    icon: Icon(
                      state.subtitles
                          ? Icons.closed_caption
                          : Icons.closed_caption_off_outlined,
                      color: state.subtitles ? PalavaColors.gold : Colors.white,
                    ),
                    onPressed: () => state.setSubtitles(!state.subtitles),
                  ),
                  IconButton(
                    tooltip: 'Episodes',
                    iconSize: 28,
                    icon: const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _showEpisodes,
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

class _EpisodePage extends StatelessWidget {
  const _EpisodePage({
    required this.series,
    required this.number,
    required this.item,
    required this.locked,
    required this.showSubtitles,
    required this.onRetry,
    required this.onUnlock,
  });

  final Series series;
  final int number;
  final FeedItem item;
  final bool locked;
  final bool showSubtitles;
  final VoidCallback onRetry;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final poster = PosterArt(series: series, showTitle: false, borderRadius: 0);
    if (locked) {
      return Stack(
        fit: StackFit.expand,
        children: [
          poster,
          ColoredBox(
            color: PalavaColors.background.withValues(alpha: 0.75),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 48, color: PalavaColors.gold),
                  const SizedBox(height: 12),
                  Text(
                    'Episode $number is locked',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onUnlock,
                    child: const Text('Unlock to keep watching'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    final player = item.player;
    return Stack(
      fit: StackFit.expand,
      children: [
        EpisodeVideo(
          controller: player,
          showSubtitles: showSubtitles,
          onRetry: onRetry,
          loadFailed: item.loadFailed,
          placeholder: poster,
          subtitleBottomPadding: 110,
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xB3000000),
                ],
                stops: [0, 0.18, 0.75, 1],
              ),
            ),
          ),
        ),
        if (player != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EpisodeProgressBar(
                  controller: player,
                  endsAt: item.episode?.endsAt,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
