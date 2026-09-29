import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '../data/models.dart';

typedef VideoControllerFactory = VideoPlayerController Function(
  Episode episode,
);

/// Creates a player for an HLS episode with its subtitles attached.
VideoPlayerController createNetworkController(Episode episode) {
  final subtitles = episode.subtitlesVtt;
  return VideoPlayerController.networkUrl(
    // Only playable (unlocked) episodes reach here.
    Uri.parse(episode.videoUrl!),
    formatHint: VideoFormat.hls,
    closedCaptionFile: subtitles == null
        ? null
        : Future.value(WebVTTCaptionFile(subtitles)),
    videoPlayerOptions: VideoPlayerOptions(
      preventsDisplaySleepDuringVideoPlayback: true,
    ),
  );
}

/// With Data saver on, pins playback to the best stream at or under
/// [maxBitrate]. With it off, lets the player choose by connection speed.
Future<void> applyDataSaver(
  VideoPlayerController controller, {
  required bool enabled,
  required int maxBitrate,
}) async {
  try {
    if (!controller.value.isInitialized ||
        !controller.isVideoTrackSupportAvailable()) {
      return;
    }
    if (!enabled) {
      await controller.selectVideoTrack(null);
      return;
    }
    final tracks = (await controller.getVideoTracks())
        .where((t) => t.bitrate != null)
        .toList();
    if (tracks.isEmpty) return;
    tracks.sort((a, b) => a.bitrate!.compareTo(b.bitrate!));
    final affordable = tracks.where((t) => t.bitrate! <= maxBitrate);
    await controller.selectVideoTrack(
      affordable.isEmpty ? tracks.first : affordable.last,
    );
  } on Object {
    // Quality selection is best-effort; playback continues either way.
  }
}

/// Holds players for a vertical list of episodes. Only the current item and
/// (when asked) the next one are kept alive, to save memory and data.
class PlayerPool {
  PlayerPool({required this.create, required this.onCreated});

  final VideoPlayerController Function(int index) create;

  /// Runs once a player has finished loading (e.g. to apply Data saver).
  final Future<void> Function(int index, VideoPlayerController controller)
  onCreated;

  final Map<int, VideoPlayerController> _players = {};
  final Map<int, Future<void>> _ready = {};

  VideoPlayerController? operator [](int index) => _players[index];

  /// Returns the player for [index], creating and loading it if needed.
  VideoPlayerController obtain(int index) {
    final existing = _players[index];
    if (existing != null) return existing;
    final controller = create(index);
    _players[index] = controller;
    _ready[index] = controller
        .initialize()
        .then((_) => onCreated(index, controller))
        .catchError((Object _) {
          // The error is kept in controller.value.errorDescription.
        });
    return controller;
  }

  /// Completes when [index] has loaded (or failed to load).
  Future<void> ready(int index) => _ready[index] ?? Future.value();

  /// Releases every player except those in [keep].
  void keepOnly(Set<int> keep) {
    for (final index in _players.keys.toList()) {
      if (!keep.contains(index)) _release(index);
    }
  }

  /// Throws away a player so the next [obtain] starts fresh (used to retry).
  void reset(int index) => _release(index);

  void pauseAll() {
    for (final controller in _players.values) {
      if (controller.value.isPlaying) controller.pause();
    }
  }

  /// Releases everything now. Only call when the screen itself is closing.
  void dispose() {
    for (final controller in _players.values) {
      controller.dispose();
    }
    _players.clear();
    _ready.clear();
  }

  void _release(int index) {
    final controller = _players.remove(index);
    _ready.remove(index);
    if (controller == null) return;
    // The page may still be sliding off screen and showing this video. Wait
    // until the next frame has been drawn without it, then free it.
    controller.pause();
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => controller.dispose())
      ..scheduleFrame();
  }
}
