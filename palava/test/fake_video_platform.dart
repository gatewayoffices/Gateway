import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Stands in for the phone's real video player during tests. Videos "load"
/// instantly and their position is set by the test.
class FakeVideoPlatform extends VideoPlayerPlatform {
  FakeVideoPlatform({this.tracks = const []});

  final List<VideoTrack> tracks;
  final Map<int, String?> created = {};
  final Set<int> playing = {};
  final Set<int> disposed = {};
  final Map<int, Duration> positions = {};
  final Map<int, VideoTrack?> selectedTrack = {};
  final List<(int, Duration)> seeks = [];
  final Map<int, StreamController<VideoEvent>> _events = {};
  int _nextId = 0;

  static const duration = Duration(minutes: 5);

  /// Players that exist and have not been disposed.
  Iterable<int> get alive => created.keys.where((id) => !disposed.contains(id));

  void setPosition(int id, Duration position) => positions[id] = position;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    created[id] = options.dataSource.uri;
    positions[id] = Duration.zero;
    _events[id] = StreamController<VideoEvent>()
      ..add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: duration,
          size: const Size(1280, 720),
        ),
      );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    playing.remove(playerId);
  }

  @override
  Future<void> play(int playerId) async => playing.add(playerId);

  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seeks.add((playerId, position));
    positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool preventsDisplaySleepDuringVideoPlayback,
  ) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();

  @override
  bool isVideoTrackSupportAvailable() => true;

  @override
  Future<List<VideoTrack>> getVideoTracks(int playerId) async => tracks;

  @override
  Future<void> selectVideoTrack(int playerId, VideoTrack? track) async {
    selectedTrack[playerId] = track;
  }
}
