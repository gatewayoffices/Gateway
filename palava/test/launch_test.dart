import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palava/data/models.dart';
import 'package:palava/data/sample_data.dart';
import 'package:palava/main.dart';
import 'package:palava/playback/watch_history.dart';
import 'package:palava/state/app_state.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

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

  testWidgets('a signed-in viewer can delete their account', (tester) async {
    final state = AppState();
    await state.verifyPhoneCode('+231770000001', '123456');
    final series = SampleData.seriesById('bride-price');
    await state.unlockWithCoins(series, 9);
    state.history.record(
      WatchEntry(
        seriesId: 'waterside',
        episodeNumber: 2,
        position: const Duration(seconds: 5),
        duration: const Duration(seconds: 75),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    await tester.pumpWidget(PalavaApp(state: state));
    await tester.pump();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delete my account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);

    // Changing your mind keeps everything.
    await tester.tap(find.text('Keep my account'));
    await tester.pumpAndSettle();
    expect(state.isSignedIn, isTrue);

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(state.isSignedIn, isFalse);
    expect(state.history.isEmpty, isTrue);
    expect(state.isUnlocked(series, 9), isFalse);
    expect(find.text('Send me a code', skipOffstage: false), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('guests see no delete option; links come from settings', (
    tester,
  ) async {
    final state = AppState()..browseAsGuest();
    await tester.pumpWidget(PalavaApp(state: state));
    await tester.pump();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Delete my account'), findsNothing);

    // No address set yet: the app says so instead of failing.
    // Scroll past it so the bottom bar does not cover it.
    await tester.scrollUntilVisible(
      find.text('Sign in'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('This page is not available yet.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  test('the links survive being cached on the phone', () {
    final config = SampleData.catalog.config;
    final withLinks = AppConfig(
      freeEpisodeCount: config.freeEpisodeCount,
      unlockCostCoins: config.unlockCostCoins,
      freeAdsPerDay: config.freeAdsPerDay,
      dataSaverMaxBitrate: config.dataSaverMaxBitrate,
      coinPacks: config.coinPacks,
      passes: config.passes,
      homeRows: config.homeRows,
      priceLabel: config.priceLabel,
      privacyUrl: 'https://palava.example/privacy',
      termsUrl: 'https://palava.example/terms',
      supportEmail: 'help@palava.example',
    );
    final back = AppConfig.fromJson(withLinks.toJson());
    expect(back.privacyUrl, 'https://palava.example/privacy');
    expect(back.termsUrl, 'https://palava.example/terms');
    expect(back.supportEmail, 'help@palava.example');
  });
}
