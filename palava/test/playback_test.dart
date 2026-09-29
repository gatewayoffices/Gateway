import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palava/data/sample_data.dart';
import 'package:palava/playback/episode_feed.dart';
import 'package:palava/playback/video_controllers.dart';
import 'package:palava/playback/watch_history.dart';
import 'package:palava/screens/for_you_screen.dart';
import 'package:palava/screens/player_screen.dart';
import 'package:palava/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as platform;

import 'fake_video_platform.dart';

late FakeVideoPlatform fake;

Widget app(AppState state, Widget home) => AppStateScope(
  state: state,
  child: MaterialApp(navigatorObservers: [playbackRouteObserver], home: home),
);

/// Lets fake players load and the position timer tick.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 600));
  }
}

/// Removes the screen so players are disposed and their timers stop.
Future<void> tearDownScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    fake = FakeVideoPlatform(
      tracks: const [
        platform.VideoTrack(id: '0_0', isSelected: false, bitrate: 1400000),
        platform.VideoTrack(id: '0_1', isSelected: false, bitrate: 400000),
        platform.VideoTrack(id: '0_2', isSelected: false, bitrate: 750000),
      ],
    );
    platform.VideoPlayerPlatform.instance = fake;
  });

  group('player', () {
    final series = SampleData.seriesById('waterside');

    testWidgets('autoplays, preloads only the next episode, then moves on', (
      tester,
    ) async {
      final state = AppState();
      await tester.pumpWidget(
        app(state, PlayerScreen(series: series, startEpisode: 1)),
      );
      await settle(tester);

      expect(find.text('Episode 1 of ${series.episodeCount}'), findsOneWidget);
      expect(fake.created.length, 1, reason: 'no preloading at the start');
      expect(fake.playing, {0});

      // Ten seconds in, the next episode loads but does not play.
      fake.setPosition(0, const Duration(seconds: 12));
      await settle(tester);
      expect(fake.created.length, 2);
      expect(fake.playing, {0});

      // At the end of the episode the player moves to episode 2 by itself
      // and reuses the preloaded video.
      fake.setPosition(0, SampleData.sampleEpisodeLength);
      await settle(tester);
      expect(find.text('Episode 2 of ${series.episodeCount}'), findsOneWidget);
      expect(fake.playing, {1});
      expect(fake.created.length, 2);

      // Releasing finishes on the real event loop, outside the test clock.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(fake.disposed, contains(0), reason: 'finished episode released');

      final saved = state.history.lastFor(series.id)!;
      expect(saved.episodeNumber, 1);
      expect(saved.isFinished, isTrue);

      await tearDownScreen(tester);
    });

    testWidgets('resumes where the viewer stopped', (tester) async {
      final state = AppState();
      state.history.record(
        WatchEntry(
          seriesId: series.id,
          episodeNumber: 3,
          position: const Duration(seconds: 20),
          duration: SampleData.sampleEpisodeLength,
          updatedAt: DateTime.now(),
        ),
      );
      await tester.pumpWidget(app(state, PlayerScreen(series: series)));
      await settle(tester);

      expect(find.text('Episode 3 of ${series.episodeCount}'), findsOneWidget);
      expect(fake.seeks, contains((0, const Duration(seconds: 20))));
      expect(fake.playing, {0});

      await tearDownScreen(tester);
    });

    testWidgets('a locked episode shows the unlock sheet instead of playing', (
      tester,
    ) async {
      final state = AppState();
      final free = state.config.freeEpisodeCount;
      await tester.pumpWidget(
        app(state, PlayerScreen(series: series, startEpisode: free)),
      );
      await settle(tester);
      fake.setPosition(0, SampleData.sampleEpisodeLength);
      await settle(tester);

      expect(find.text('Episode ${free + 1} is locked'), findsWidgets);
      expect(find.text('Unlock with 30 coins'), findsOneWidget);
      expect(fake.playing, isEmpty);

      await tester.tap(find.text('Unlock with 30 coins'));
      await settle(tester);
      expect(state.isUnlocked(series.id, free + 1), isTrue);
      expect(fake.playing.length, 1, reason: 'plays once unlocked');

      await tearDownScreen(tester);
    });

    testWidgets('subtitles button turns subtitles off and on', (tester) async {
      final state = AppState();
      await tester.pumpWidget(
        app(state, PlayerScreen(series: series, startEpisode: 1)),
      );
      await settle(tester);
      expect(state.subtitles, isTrue);

      await tester.tap(find.byTooltip('Turn subtitles off'));
      await tester.pump();
      expect(state.subtitles, isFalse);
      expect(find.byTooltip('Turn subtitles on'), findsOneWidget);

      await tearDownScreen(tester);
    });
  });

  group('For You feed', () {
    testWidgets('loads nothing until its tab is open', (tester) async {
      final state = AppState();
      await tester.pumpWidget(
        app(state, const Scaffold(body: ForYouScreen(isActive: false))),
      );
      await settle(tester);
      expect(fake.created, isEmpty);

      await tester.pumpWidget(
        app(state, const Scaffold(body: ForYouScreen(isActive: true))),
      );
      await settle(tester);
      expect(fake.created.length, 1);
      expect(fake.playing, {0});

      await tester.pumpWidget(
        app(state, const Scaffold(body: ForYouScreen(isActive: false))),
      );
      await settle(tester);
      expect(fake.playing, isEmpty, reason: 'pauses when leaving the tab');

      await tearDownScreen(tester);
    });
  });

  group('data saver', () {
    Future<VideoPlayerController> loadedPlayer() async {
      final player = createNetworkController(
        SampleData.episodesFor(SampleData.series.first).first,
      );
      await player.initialize();
      return player;
    }

    test('picks the best stream under the limit', () async {
      final player = await loadedPlayer();
      await applyDataSaver(player, enabled: true, maxBitrate: 800000);
      expect(fake.selectedTrack[0]?.bitrate, 750000);
      await player.dispose();
    });

    test('falls back to the smallest stream when all are over', () async {
      final player = await loadedPlayer();
      await applyDataSaver(player, enabled: true, maxBitrate: 100000);
      expect(fake.selectedTrack[0]?.bitrate, 400000);
      await player.dispose();
    });

    test('lets the player choose when off', () async {
      final player = await loadedPlayer();
      await applyDataSaver(player, enabled: false, maxBitrate: 800000);
      expect(fake.selectedTrack.containsKey(0), isTrue);
      expect(fake.selectedTrack[0], isNull);
      await player.dispose();
    });
  });

  test('watch history survives an app restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    WatchHistory(prefs).record(
      WatchEntry(
        seriesId: 'waterside',
        episodeNumber: 4,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 75),
        updatedAt: DateTime(2026, 9, 29),
      ),
    );
    final reloaded = WatchHistory(prefs).lastFor('waterside')!;
    expect(reloaded.episodeNumber, 4);
    expect(reloaded.position, const Duration(seconds: 30));
    expect(AppState(prefs: prefs).continueWatching.first.seriesId, 'waterside');
  });

  test('sample subtitles are valid WebVTT', () {
    final episode = SampleData.episodesFor(SampleData.series.first).first;
    final captions = WebVTTCaptionFile(episode.subtitlesVtt!).captions;
    expect(captions, hasLength(12));
    expect(captions.first.start, const Duration(seconds: 1));
    expect(captions.first.text, 'Where were you last night?');
  });
}
