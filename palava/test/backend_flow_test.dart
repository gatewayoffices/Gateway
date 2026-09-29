import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palava/backend/backend.dart';
import 'package:palava/backend/sample_backend.dart';
import 'package:palava/data/models.dart';
import 'package:palava/data/sample_data.dart';
import 'package:palava/main.dart';
import 'package:palava/playback/watch_history.dart';
import 'package:palava/screens/unlock_sheet.dart';
import 'package:palava/state/app_state.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// Behaves like the real server: no bundled catalog, guests cannot unlock.
class FakeServer extends SampleBackend {
  FakeServer({this.failCatalogTimes = 0, this.serverHistory = const []});

  int failCatalogTimes;
  final List<WatchEntry> serverHistory;
  final List<WatchEntry> uploaded = [];
  bool refuseUnlocks = false;

  @override
  bool get isSample => false;

  @override
  Catalog? get cachedCatalog => null;

  @override
  Future<Catalog> loadCatalog() async {
    if (failCatalogTimes > 0) {
      failCatalogTimes--;
      throw const BackendException(BackendErrorKind.offline);
    }
    return SampleData.catalog;
  }

  @override
  Future<ViewerData> loadViewer() async {
    final base = snapshot();
    return ViewerData(
      coinBalance: base.coinBalance,
      adsLeftToday: base.adsLeftToday,
      unlocked: base.unlocked,
      myList: base.myList,
      liked: base.liked,
      history: serverHistory,
      phone: base.phone,
    );
  }

  @override
  Future<int> unlockWithCoins(Series series, int episodeNumber) async {
    if (refuseUnlocks) {
      throw const BackendException(BackendErrorKind.notEnoughCoins);
    }
    return super.unlockWithCoins(series, episodeNumber);
  }

  @override
  Future<void> saveProgress(WatchEntry entry) async => uploaded.add(entry);
}

Future<void> pumpApp(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(PalavaApp(state: state));
  await tester.pump();
}

void main() {
  setUp(() {
    VideoPlayerPlatform.instance = FakeVideoPlatform();
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

  testWidgets('signing in with a phone code opens Home', (tester) async {
    final state = AppState();
    await pumpApp(tester, state);

    await tester.scrollUntilVisible(find.text('Browse as a guest'), 200);
    await tester.enterText(find.byType(TextField), '0770 123 456');
    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your code'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('Verify'));
    await tester.pump();
    expect(find.text('Enter the 6-digit code.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(state.isSignedIn, isTrue);
    expect(find.text('Continue watching'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    // The leading 0 is dropped: +231 770 123 456.
    expect(find.text('+231 ** *** 456'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Log out'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(state.isSignedIn, isFalse);
    await tester.scrollUntilVisible(find.text('Send me a code'), 200);
    expect(find.text('Send me a code'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows a retry screen when the catalog cannot load', (
    tester,
  ) async {
    final state = AppState(backend: FakeServer(failCatalogTimes: 1));
    await pumpApp(tester, state);
    expect(state.phase, AppPhase.loading);

    await state.start();
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(state.phase, AppPhase.ready);
    await tester.scrollUntilVisible(find.text('Browse as a guest'), 200);
    expect(find.text('Browse as a guest'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with the real server, guests are asked to sign in to unlock', (
    tester,
  ) async {
    final state = AppState(backend: FakeServer());
    await state.refreshCatalog();
    state.browseAsGuest();
    await pumpApp(tester, state);

    final series = state.catalog.seriesById('bride-price')!;
    showUnlockSheet(
      tester.element(find.byType(Scaffold).first),
      series: series,
      episodeNumber: 9,
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to unlock'), findsOneWidget);
    expect(find.text('Unlock with 30 coins'), findsNothing);

    await tester.tap(find.text('Sign in to unlock'));
    await tester.pumpAndSettle();
    expect(state.enteredApp, isFalse);
    await tester.scrollUntilVisible(find.text('Send me a code'), 200);
    expect(find.text('Send me a code'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the unlock sheet explains a refusal from the server', (
    tester,
  ) async {
    final server = FakeServer()..refuseUnlocks = true;
    final state = AppState(backend: server);
    await state.refreshCatalog();
    await state.verifyPhoneCode('+231770000001', '123456');
    await pumpApp(tester, state);

    final series = state.catalog.seriesById('bride-price')!;
    showUnlockSheet(
      tester.element(find.byType(Scaffold).first),
      series: series,
      episodeNumber: 9,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock with 30 coins'));
    await tester.pumpAndSettle();
    expect(find.text('You do not have enough coins.'), findsOneWidget);
    expect(state.isUnlocked(series, 9), isFalse);

    await tester.pumpWidget(const SizedBox());
  });

  test('signing in merges watch history both ways', () async {
    final old = DateTime(2026, 9, 1);
    final recent = DateTime(2026, 9, 28);
    final server = FakeServer(
      serverHistory: [
        WatchEntry(
          seriesId: 'waterside',
          episodeNumber: 7,
          position: const Duration(seconds: 5),
          duration: const Duration(seconds: 75),
          updatedAt: recent,
        ),
        WatchEntry(
          seriesId: 'palm-wine',
          episodeNumber: 2,
          position: const Duration(seconds: 5),
          duration: const Duration(seconds: 75),
          updatedAt: old,
        ),
      ],
    );
    final state = AppState(backend: server);
    await state.refreshCatalog();
    // Watched as a guest on this phone before signing in.
    state.history
      ..record(
        WatchEntry(
          seriesId: 'waterside',
          episodeNumber: 3,
          position: const Duration(seconds: 5),
          duration: const Duration(seconds: 75),
          updatedAt: old,
        ),
      )
      ..record(
        WatchEntry(
          seriesId: 'palm-wine',
          episodeNumber: 4,
          position: const Duration(seconds: 5),
          duration: const Duration(seconds: 75),
          updatedAt: recent,
        ),
      );

    await state.verifyPhoneCode('+231770000001', '123456');

    expect(state.history.lastFor('waterside')!.episodeNumber, 7);
    expect(state.history.lastFor('palm-wine')!.episodeNumber, 4);
    expect(server.uploaded.map((e) => e.seriesId), ['palm-wine']);
  });

  test('with the real server, Continue watching starts empty', () async {
    final state = AppState(backend: FakeServer());
    await state.refreshCatalog();
    expect(state.continueWatching, isEmpty);
    expect(AppState().continueWatching, isNotEmpty);
  });

  test('the catalog survives being saved and read back', () {
    final copy = Catalog.fromJson(SampleData.catalog.toJson());
    expect(copy.series.map((s) => s.id), SampleData.series.map((s) => s.id));
    expect(
      copy.series.first.posterColors,
      SampleData.series.first.posterColors,
    );
    expect(copy.featured?.id, SampleData.featuredSeriesId);
    expect(copy.config.coinPacks.last.bonusCoins, 150);
    expect(copy.config.homeRows.first.title, 'Trending in Monrovia');
  });
}
