import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:palava/data/models.dart';
import 'package:palava/data/sample_data.dart';
import 'package:palava/downloads/download_manager.dart';
import 'package:palava/downloads/hls_downloader.dart';
import 'package:palava/screens/downloads_screen.dart';
import 'package:palava/state/app_state.dart';

/// A pretend video host with the same layout as the real test streams: a
/// master playlist with several qualities (one with surround sound), audio
/// tracks, and 4-second pieces with an init file.
class FakeVideoServer {
  final requests = <String>[];

  Uri get master => Uri.parse('https://video.example/show/hls.m3u8');

  late final client = MockClient((request) async {
    final path = request.url.path;
    requests.add(path);
    if (path == '/show/hls.m3u8') return http.Response(_master, 200);
    if (path == '/locked/hls.m3u8') {
      return http.Response(media('v', encrypted: true), 200);
    }
    if (path.endsWith('.m3u8')) {
      return http.Response(
        media(path.split('/').last.replaceAll('.m3u8', '')),
        200,
      );
    }
    if (path.endsWith('.mp4')) {
      return http.Response.bytes(List.filled(1000, 7), 200);
    }
    return http.Response('', 404);
  });

  static const _master = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,URI="audio/de.m3u8",GROUP-ID="aud",LANGUAGE="de",NAME="de",CHANNELS="2"
#EXT-X-MEDIA:TYPE=AUDIO,URI="audio/en.m3u8",GROUP-ID="aud",LANGUAGE="en",NAME="en",DEFAULT=YES,CHANNELS="2"
#EXT-X-MEDIA:TYPE=SUBTITLES,URI="subs/en.m3u8",GROUP-ID="sub",LANGUAGE="en",NAME="en"
#EXT-X-STREAM-INF:BANDWIDTH=2000000,AVERAGE-BANDWIDTH=1500000,CODECS="avc1.4d401f,mp4a.40.2",RESOLUTION=640x480,AUDIO="aud"
video/480.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=900000,AVERAGE-BANDWIDTH=700000,CODECS="avc1.4d401f,ac-3",RESOLUTION=480x360,AUDIO="aud"
video/surround.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=900000,AVERAGE-BANDWIDTH=600000,CODECS="avc1.4d401f,mp4a.40.2",RESOLUTION=320x240,AUDIO="aud"
video/240.m3u8
''';

  static String media(String name, {bool encrypted = false}) => [
    '#EXTM3U',
    '#EXT-X-VERSION:6',
    '#EXT-X-TARGETDURATION:4',
    if (encrypted) '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"',
    '#EXT-X-MAP:URI="$name-init.mp4"',
    for (var i = 1; i <= 6; i++) ...['#EXTINF:4.000,', '$name-s$i.mp4'],
    '#EXT-X-ENDLIST',
  ].join('\n');
}

class FakeNetwork implements NetworkStatus {
  bool wifi = false;
  final _changes = StreamController<void>.broadcast();

  @override
  Future<bool> isUnmetered() async => wifi;

  @override
  Stream<void> get changes => _changes.stream;

  void connectWifi() {
    wifi = true;
    _changes.add(null);
  }
}

/// Saves a small file instead of going to the network.
class InstantDownloader extends HlsDownloader {
  final sources = <Uri>[];

  @override
  Future<HlsDownload> download({
    required Uri source,
    required Directory dir,
    required int maxBitrate,
    Duration? limit,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    sources.add(source);
    await dir.create(recursive: true);
    final entry = File('${dir.path}/index.m3u8');
    await entry.writeAsString('#EXTM3U');
    onProgress?.call(1);
    return HlsDownload(entry: entry, bytes: 6200000);
  }
}

/// Lets the downloads (real file writes) finish.
Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 200));

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('palava_downloads');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('HlsDownloader', () {
    final server = FakeVideoServer();
    HlsDownloader downloader() => HlsDownloader(client: server.client);

    test('saves one data-saver quality and stops at the episode end', () async {
      final progress = <double>[];
      final result = await downloader().download(
        source: server.master,
        dir: Directory('${temp.path}/ep1'),
        maxBitrate: 800000,
        limit: const Duration(seconds: 9),
        onProgress: progress.add,
      );

      final dir = Directory('${temp.path}/ep1');
      final master = await File('${dir.path}/index.m3u8').readAsString();
      // 240p: the best stereo quality under the limit (the surround one and
      // the 480p one are skipped).
      expect(master, contains('RESOLUTION=320x240'));
      expect(master, contains('URI="audio.m3u8"'));
      expect(master, isNot(contains('http')));

      final video = await File('${dir.path}/video.m3u8').readAsString();
      // 9 seconds needs 3 pieces of 4 seconds.
      expect('#EXTINF'.allMatches(video), hasLength(3));
      expect(video, contains('#EXT-X-MAP:URI="v0.mp4"'));
      expect(video.trim(), endsWith('#EXT-X-ENDLIST'));
      expect(await File('${dir.path}/v3.mp4').exists(), isTrue);

      // The English (default) audio, not German; no subtitles fetched.
      expect(server.requests, contains('/show/audio/en.m3u8'));
      expect(server.requests, isNot(contains('/show/audio/de.m3u8')));
      expect(server.requests.where((r) => r.contains('subs')), isEmpty);
      expect(server.requests, isNot(contains('/show/video/480.m3u8')));

      // 2 init files + 3 video + 3 audio pieces of 1000 bytes.
      expect(result.bytes, 8000);
      expect(result.entry.path, endsWith('ep1/index.m3u8'));
      expect(progress.last, 1);
      expect(await Directory('${dir.path}.part').exists(), isFalse);
    });

    test('a single-quality stream is saved whole', () async {
      final source = server.master.resolve('/single/v.m3u8');
      server.requests.clear();
      final result = await downloader().download(
        source: source,
        dir: Directory('${temp.path}/ep2'),
        maxBitrate: 800000,
      );
      expect(result.entry.path, endsWith('video.m3u8'));
      final video = await result.entry.readAsString();
      expect('#EXTINF'.allMatches(video), hasLength(6));
    });

    test('protected streams and cancelled downloads leave nothing', () async {
      await expectLater(
        downloader().download(
          source: server.master.resolve('/locked/hls.m3u8'),
          dir: Directory('${temp.path}/locked'),
          maxBitrate: 800000,
        ),
        throwsA(isA<DownloadException>()),
      );
      expect(await Directory('${temp.path}/locked.part').exists(), isFalse);

      var pieces = 0;
      await expectLater(
        downloader().download(
          source: server.master,
          dir: Directory('${temp.path}/stopped'),
          maxBitrate: 800000,
          onProgress: (_) => pieces++,
          isCancelled: () => pieces >= 2,
        ),
        throwsA(isA<DownloadCancelled>()),
      );
      expect(await Directory('${temp.path}/stopped').exists(), isFalse);
      expect(await Directory('${temp.path}/stopped.part').exists(), isFalse);
    });
  });

  group('DownloadManager', () {
    final series = SampleData.seriesById('bride-price');

    DownloadManager manager(
      FakeNetwork network,
      InstantDownloader downloader, {
      bool wifiOnly = true,
    }) => DownloadManager(
      root: Directory('${temp.path}/downloads'),
      resolve: (id, n) async => n > 8
          ? Episode(seriesId: id, number: n)
          : Episode(
              seriesId: id,
              number: n,
              videoUrl: 'https://video.example/$id/$n.m3u8',
              subtitlesVtt: 'WEBVTT',
              endsAt: const Duration(seconds: 75),
            ),
      wifiOnly: () => wifiOnly,
      maxBitrate: () => 800000,
      network: network,
      downloader: downloader,
    );

    test('waits for WiFi, then saves and plays offline', () async {
      final network = FakeNetwork();
      final downloader = InstantDownloader();
      final downloads = manager(network, downloader);
      await downloads.load();

      expect(downloads.add(series, [1, 2]), 2);
      await settle();
      expect(
        downloads.item('bride-price', 1)!.state,
        DownloadState.waitingForWifi,
      );
      expect(downloader.sources, isEmpty);

      network.connectWifi();
      await settle();
      expect(downloads.item('bride-price', 2)!.state, DownloadState.done);
      expect(downloads.totalBytes, 12400000);

      final offline = downloads.offlineEpisode('bride-price', 1)!;
      expect(offline.videoUrl, startsWith('file://'));
      expect(offline.videoUrl, endsWith('bride-price/1/index.m3u8'));
      expect(offline.subtitlesVtt, 'WEBVTT');
      expect(offline.endsAt, const Duration(seconds: 75));

      // Adding the same episode again does nothing.
      expect(downloads.add(series, [1]), 0);

      // A fresh start remembers what was saved.
      final again = manager(FakeNetwork(), InstantDownloader());
      await again.load();
      expect(again.doneCount, 2);
      expect(again.offlineEpisode('bride-price', 2), isNotNull);

      await again.remove('bride-price', 2);
      expect(again.offlineEpisode('bride-price', 2), isNull);
      expect(
        await Directory('${temp.path}/downloads/bride-price/2').exists(),
        isFalse,
      );
      await again.removeAll();
      expect(again.items, isEmpty);
    });

    test('mobile data is used when WiFi-only is off', () async {
      final downloads = manager(
        FakeNetwork(),
        InstantDownloader(),
        wifiOnly: false,
      );
      await downloads.load();
      downloads.add(series, [3]);
      await settle();
      expect(downloads.item('bride-price', 3)!.isDone, isTrue);
    });

    test('locked episodes fail with a reason and can be retried', () async {
      final downloads = manager(
        FakeNetwork(),
        InstantDownloader(),
        wifiOnly: false,
      );
      await downloads.load();
      downloads.add(series, [12]);
      await settle();
      final item = downloads.item('bride-price', 12)!;
      expect(item.state, DownloadState.failed);
      expect(item.error, 'Unlock this episode to download it.');
      downloads.retry('bride-price', 12);
      await settle();
      expect(item.state, DownloadState.failed);
    });

    test('episodes saved during a pass stop playing when it ends', () async {
      final downloads = manager(
        FakeNetwork(),
        InstantDownloader(),
        wifiOnly: false,
      );
      await downloads.load();
      downloads.add(
        series,
        [5, 6],
        playableUntil: (n) => n == 5
            ? DateTime.now().subtract(const Duration(minutes: 1))
            : DateTime.now().add(const Duration(hours: 1)),
      );
      await settle();
      expect(downloads.offlineEpisode('bride-price', 5), isNull);
      expect(downloads.offlineEpisode('bride-price', 6), isNotNull);
    });
  });

  group('screens', () {
    setUp(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1080, 2280);
      view.devicePixelRatio = 3;
    });
    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    testWidgets('download a series, then see and delete it in Profile', (
      tester,
    ) async {
      final network = FakeNetwork();
      final state = AppState(
        downloadsDir: Directory('${temp.path}/app'),
        network: network,
        downloader: InstantDownloader(),
      );
      final series = SampleData.seriesById('bride-price');
      await tester.runAsync(() => state.downloads!.load());
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => showDownloadSheet(context, series),
                      child: const Text('sheet'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DownloadsScreen(),
                        ),
                      ),
                      child: const Text('downloads'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('sheet'));
      await tester.pumpAndSettle();
      // 8 free episodes can be saved; episode 9 is locked.
      expect(find.text('Download all open episodes (8)'), findsOneWidget);
      expect(find.textContaining('WiFi only'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Episode 9'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Unlock to download'), findsWidgets);

      await tester.tap(find.text('Download all open episodes (8)'));
      await tester.runAsync(settle);
      await tester.pump();
      expect(find.text('Waiting for WiFi', skipOffstage: false), findsWidgets);

      await tester.runAsync(() async {
        network.connectWifi();
        await settle();
      });
      await tester.pump();
      expect(find.text('All open episodes are saved'), findsOneWidget);
      expect(state.downloads!.doneCount, 8);

      Navigator.of(tester.element(find.text('sheet'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('downloads'));
      await tester.pumpAndSettle();
      expect(
        find.text('8 episodes saved  ·  49.6 MB on this phone'),
        findsOneWidget,
      );
      expect(find.text('The Bride Price'), findsOneWidget);

      await tester.ensureVisible(find.text('Delete all downloads'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete all downloads'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete all'));
      await tester.runAsync(settle);
      await tester.pumpAndSettle();
      expect(find.textContaining('No downloads yet'), findsOneWidget);
    });

    test('the app plays the saved copy and treats it as open', () async {
      final state = AppState(
        downloadsDir: Directory('${temp.path}/app2'),
        network: FakeNetwork()..wifi = true,
        downloader: InstantDownloader(),
      );
      await state.downloads!.load();
      final series = SampleData.seriesById('bride-price');
      expect(state.downloadEpisode(series, 12), isFalse, reason: 'locked');
      expect(state.downloadEpisode(series, 3), isTrue);
      await settle();
      final episode = await state.loadEpisode(series, 3);
      expect(episode.videoUrl, startsWith('file://'));
      final online = await state.loadEpisode(series, 4);
      expect(online.videoUrl, startsWith('https://'));
      state.dispose();
    });
  });
}
