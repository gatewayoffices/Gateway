import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import 'video_controllers.dart';

/// Lets screens pause playback when another page or sheet covers them.
/// Registered in `MaterialApp.navigatorObservers`.
final playbackRouteObserver = RouteObserver<ModalRoute<dynamic>>();

/// How far into an item the next one starts loading. Waiting until the viewer
/// is clearly watching avoids spending data on episodes they swipe past.
const _preloadAfter = Duration(seconds: 10);

/// What a page of the feed has to show.
class FeedItem {
  const FeedItem({this.episode, this.player, this.loadFailed = false});

  /// Null until the episode's details have loaded.
  final Episode? episode;

  /// Null while locked, loading, or not yet needed.
  final VideoPlayerController? player;

  /// The episode's details could not be fetched (e.g. offline).
  final bool loadFailed;
}

/// Controls an [EpisodeFeed] from outside (buttons in overlays and sheets).
class EpisodeFeedController {
  _EpisodeFeedState? _state;

  int get index => _state?._index ?? 0;

  VideoPlayerController? get currentPlayer =>
      _state?._pool[_state?._index ?? -1];

  void jumpTo(int index) => _state?._jumpTo(index);

  /// Re-checks the current item, e.g. after it was unlocked.
  void refreshCurrent() => _state?._activate(index);

  /// Drops a failed item and loads it again.
  void retry(int index) => _state?._retry(index);
}

/// Full-screen vertical list of episodes: swipe up for the next one. The
/// current item autoplays, the next one preloads once the viewer is engaged,
/// and at the end of an item the feed moves on by itself.
class EpisodeFeed extends StatefulWidget {
  const EpisodeFeed({
    super.key,
    required this.itemCount,
    required this.loadEpisode,
    required this.itemBuilder,
    this.controller,
    this.initialIndex = 0,
    this.initialPosition,
    this.active = true,
    this.isLocked,
    this.onLocked,
    this.onIndexChanged,
    this.onProgress,
    this.onFinishedLast,
  });

  final int itemCount;

  /// Fetches an episode with its video link. Called again after an unlock,
  /// since the link only becomes available then.
  final Future<Episode> Function(int index) loadEpisode;

  /// Builds one page.
  final Widget Function(BuildContext context, int index, FeedItem item)
  itemBuilder;

  final EpisodeFeedController? controller;
  final int initialIndex;

  /// Where to start the first item (resume).
  final Duration? initialPosition;

  /// False while the feed is off screen (another tab); nothing plays or loads.
  final bool active;

  final bool Function(int index)? isLocked;

  /// Called on arriving at a locked item. When it completes, the item is
  /// checked again and plays if it is now unlocked.
  final Future<void> Function(int index)? onLocked;

  final ValueChanged<int>? onIndexChanged;

  /// Reports progress every few seconds, and with [leaving] true when the
  /// viewer moves away from the item or it finishes.
  final void Function(
    int index,
    Duration position,
    Duration length, {
    required bool leaving,
  })?
  onProgress;

  /// The last item finished playing.
  final VoidCallback? onFinishedLast;

  @override
  State<EpisodeFeed> createState() => _EpisodeFeedState();
}

class _EpisodeFeedState extends State<EpisodeFeed> with RouteAware {
  late final PageController _pages;
  late final PlayerPool _pool;
  late int _index;

  /// Episodes fetched so far, with their video links when watchable.
  final Map<int, Episode> _episodes = {};
  final Set<int> _failed = {};
  int? _pendingSeekIndex;
  Duration? _pendingSeek;

  VideoPlayerController? _listening;
  bool _finishedCurrent = false;
  bool _covered = false;
  bool _resumeWhenUncovered = false;
  bool _subscribed = false;
  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);

  /// Increases on every activation so stale async work can bail out.
  int _activation = 0;

  bool get _canPlay => widget.active && !_covered;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _index = widget.initialIndex;
    _pendingSeekIndex = widget.initialIndex;
    _pendingSeek = widget.initialPosition;
    _pages = PageController(initialPage: widget.initialIndex);
    final appState = AppStateScope.read(context);
    _pool = PlayerPool(
      create: (i) => appState.createVideoController(_episodes[i]!),
      onCreated: (i, player) => applyDataSaver(
        player,
        enabled: appState.dataSaver,
        maxBitrate: appState.config.dataSaverMaxBitrate,
      ),
    );
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _activate(_index);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_subscribed && route != null) {
      playbackRouteObserver.subscribe(this, route);
      _subscribed = true;
    }
  }

  @override
  void didUpdateWidget(EpisodeFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    if (oldWidget.active != widget.active) {
      if (!widget.active) {
        _pool.pauseAll();
      } else if (_pool[_index] == null) {
        _activate(_index);
      } else if (!_covered) {
        _pool[_index]!.play();
      }
    }
  }

  @override
  void dispose() {
    _reportLeaving();
    if (_subscribed) playbackRouteObserver.unsubscribe(this);
    _listening?.removeListener(_onTick);
    _pool.dispose();
    _pages.dispose();
    if (widget.controller?._state == this) widget.controller?._state = null;
    super.dispose();
  }

  // Another page or sheet was pushed on top of this one.
  @override
  void didPushNext() {
    _covered = true;
    _resumeWhenUncovered = _pool[_index]?.value.isPlaying ?? false;
    _pool.pauseAll();
  }

  // The page or sheet on top was closed.
  @override
  void didPopNext() {
    _covered = false;
    if (_resumeWhenUncovered && widget.active) _pool[_index]?.play();
  }

  void _jumpTo(int index) {
    if (index == _index) {
      _activate(index);
    } else {
      _pages.jumpToPage(index);
    }
  }

  void _retry(int index) {
    _pool.reset(index);
    _episodes.remove(index);
    _failed.remove(index);
    if (index == _index) _activate(index);
  }

  /// Makes sure [index] has its details and, if watchable, its video link.
  /// Returns false if they could not be fetched.
  Future<bool> _ensureEpisode(int index) async {
    final known = _episodes[index];
    if (known != null && known.isPlayable) return true;
    try {
      _episodes[index] = await widget.loadEpisode(index);
      _failed.remove(index);
      return true;
    } on Object {
      _failed.add(index);
      return false;
    }
  }

  bool _locked(int index) => widget.isLocked?.call(index) ?? false;

  Duration _length(int index, VideoPlayerValue value) {
    final endsAt = _episodes[index]?.endsAt;
    if (endsAt == null || value.duration == Duration.zero) {
      return value.duration;
    }
    return endsAt < value.duration ? endsAt : value.duration;
  }

  Future<void> _activate(int index) async {
    final token = ++_activation;
    if (index != _index) _reportLeaving();
    _listening?.removeListener(_onTick);
    _listening = null;
    if (index != _index) {
      _index = index;
      widget.onIndexChanged?.call(index);
    }
    _finishedCurrent = false;

    // Keep only this item and an already-loaded neighbour after it.
    _pool.keepOnly({index, if (_pool[index + 1] != null) index + 1});

    if (_locked(index)) {
      _pool.keepOnly(const {});
      setState(() {});
      await widget.onLocked?.call(index);
      if (!mounted || token != _activation || _locked(index)) {
        if (mounted) setState(() {});
        return;
      }
    }
    if (!widget.active) return;

    if (!await _ensureEpisode(index)) {
      if (mounted) setState(() {});
      return;
    }
    if (!mounted || token != _activation) return;
    if (!_episodes[index]!.isPlayable) {
      // The server still considers it locked (e.g. unlocked on another
      // phone that has not synced); show it as locked.
      setState(() {});
      return;
    }

    final player = _pool.obtain(index);
    player.addListener(_onTick);
    _listening = player;
    setState(() {});

    await _pool.ready(index);
    if (!mounted || token != _activation || !player.value.isInitialized) {
      return;
    }
    if (_pendingSeekIndex == index && _pendingSeek != null) {
      await player.seekTo(_pendingSeek!);
    } else if (player.value.position >= _length(index, player.value)) {
      await player.seekTo(Duration.zero);
    }
    _pendingSeekIndex = null;
    _pendingSeek = null;
    if (mounted && token == _activation && _canPlay) await player.play();
  }

  void _onTick() {
    final player = _listening;
    if (player == null || !player.value.isInitialized) return;
    final value = player.value;
    final index = _index;
    final length = _length(index, value);

    final next = index + 1;
    if (next < widget.itemCount &&
        _pool[next] == null &&
        !_preloading.contains(next) &&
        !_locked(next) &&
        value.position >= _preloadAfter) {
      _preload(next);
    }

    final now = DateTime.now();
    if (value.isPlaying && now.difference(_lastReport).inSeconds >= 5) {
      _lastReport = now;
      widget.onProgress?.call(index, value.position, length, leaving: false);
    }

    final reachedEnd =
        value.isCompleted ||
        (length > Duration.zero && value.position >= length);
    if (!_finishedCurrent && reachedEnd) {
      _finishedCurrent = true;
      player.pause();
      widget.onProgress?.call(index, length, length, leaving: true);
      if (next < widget.itemCount) {
        _pages.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      } else {
        widget.onFinishedLast?.call();
      }
    }
  }

  final Set<int> _preloading = {};

  Future<void> _preload(int index) async {
    _preloading.add(index);
    final ok = await _ensureEpisode(index);
    _preloading.remove(index);
    if (!mounted || !ok || !_episodes[index]!.isPlayable) return;
    // Still wanted: the viewer has not moved away in the meantime.
    if (index == _index + 1 && _pool[index] == null) {
      _pool.obtain(index);
      setState(() {});
    }
  }

  void _reportLeaving() {
    final player = _listening;
    if (player == null || !player.value.isInitialized || _finishedCurrent) {
      return;
    }
    widget.onProgress?.call(
      _index,
      player.value.position,
      _length(_index, player.value),
      leaving: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pages,
      scrollDirection: Axis.vertical,
      itemCount: widget.itemCount,
      onPageChanged: _activate,
      itemBuilder: (context, index) => widget.itemBuilder(
        context,
        index,
        FeedItem(
          episode: _episodes[index],
          player: _locked(index) ? null : _pool[index],
          loadFailed: _failed.contains(index),
        ),
      ),
    );
  }
}
