import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palava/ads/rewarded_ads.dart';
import 'package:palava/backend/backend.dart';
import 'package:palava/backend/sample_backend.dart';
import 'package:palava/data/models.dart';
import 'package:palava/data/sample_data.dart';
import 'package:palava/screens/unlock_sheet.dart';
import 'package:palava/screens/wallet_screen.dart';
import 'package:palava/state/app_state.dart';

/// Like the real server in test mode: purchases wait for an admin.
class TestModeServer extends SampleBackend {
  TestModeServer({this.mode = PaymentMode.test});

  final PaymentMode mode;
  final List<PurchaseSummary> pending = [];

  @override
  bool get isSample => false;

  @override
  Catalog? get cachedCatalog => null;

  @override
  Future<Catalog> loadCatalog() async {
    final c = SampleData.catalog;
    final config = c.config;
    return Catalog(
      series: c.series,
      featuredSeriesId: c.featuredSeriesId,
      forYouSeriesIds: c.forYouSeriesIds,
      config: AppConfig(
        freeEpisodeCount: config.freeEpisodeCount,
        unlockCostCoins: config.unlockCostCoins,
        freeAdsPerDay: config.freeAdsPerDay,
        dataSaverMaxBitrate: config.dataSaverMaxBitrate,
        coinPacks: config.coinPacks,
        passes: config.passes,
        homeRows: config.homeRows,
        priceLabel: config.priceLabel,
        paymentMode: mode,
      ),
    );
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
      history: const [],
      recentPurchases: [...pending.reversed],
    );
  }

  @override
  Future<PurchaseTicket> startPurchase({
    int? coinPackId,
    String? passId,
    required String paymentMethod,
  }) async {
    final reference = 'PAL-TEST${pending.length + 1}';
    pending.add(
      PurchaseSummary(
        reference: reference,
        productName: passId ?? 'coins',
        status: PurchaseStatus.pending,
        createdAt: DateTime(2026, 10, 2, 14, 5),
      ),
    );
    return PurchaseTicket(id: pending.length, reference: reference);
  }
}

class ScriptedAds implements RewardedAds {
  ScriptedAds(this.outcome);

  AdOutcome outcome;
  int shown = 0;

  @override
  Future<AdOutcome> show() async {
    shown++;
    return outcome;
  }
}

Future<void> openWallet(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(
    AppStateScope(
      state: state,
      child: const MaterialApp(home: WalletScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> pay(WidgetTester tester) async {
  // A message from an earlier tap would cover the button.
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .removeCurrentSnackBar();
  await tester.pump();
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
}

void main() {
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

  testWidgets('sample mode: a coin pack adds coins, a pass opens everything', (
    tester,
  ) async {
    final state = AppState();
    final series = SampleData.seriesById('bride-price');
    await openWallet(tester, state);

    final before = state.coinBalance;
    await choose(tester, '300');
    await pay(tester);
    expect(state.coinBalance, before + 320);

    expect(state.isUnlocked(series, 30), isFalse);
    await choose(tester, 'Day pass');
    await pay(tester);
    expect(state.isUnlocked(series, 30), isTrue);
    await tester.scrollUntilVisible(
      find.text('Pass active'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pass active'), findsOneWidget);
    expect(find.text('Recent payments'), findsOneWidget);
  });

  testWidgets('test mode: the payment waits for an admin to confirm it', (
    tester,
  ) async {
    final server = TestModeServer();
    final state = AppState(backend: server);
    await state.refreshCatalog();
    await state.verifyPhoneCode('+231770000001', '123456');
    await openWallet(tester, state);

    final before = state.coinBalance;
    await choose(tester, 'Week pass');
    await choose(tester, 'Orange Money');
    await pay(tester);
    expect(find.text('Test payment started'), findsOneWidget);
    expect(find.text('PAL-TEST1'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(state.coinBalance, before);
    expect(state.hasActivePass, isFalse);
    await tester.scrollUntilVisible(
      find.text('Waiting'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Waiting'), findsOneWidget);
  });

  testWidgets('payments switched off, and guests on the real server', (
    tester,
  ) async {
    final state = AppState(backend: TestModeServer(mode: PaymentMode.off));
    await state.refreshCatalog();
    await openWallet(tester, state);
    await choose(tester, 'Day pass');
    await pay(tester);
    expect(find.text('Sign in to buy coins and passes.'), findsOneWidget);

    await state.verifyPhoneCode('+231770000001', '123456');
    await pay(tester);
    expect(find.text('Payments are not open yet.'), findsOneWidget);
  });

  group('rewarded ads', () {
    Future<AppState> showSheet(WidgetTester tester, RewardedAds ads) async {
      final state = AppState(rewardedAds: ads);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showUnlockSheet(
                    context,
                    series: SampleData.seriesById('bride-price'),
                    episodeNumber: 9,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('an ad watched to the end unlocks the episode', (tester) async {
      final ads = ScriptedAds(AdOutcome.rewarded);
      final state = await showSheet(tester, ads);
      final series = SampleData.seriesById('bride-price');
      await tester.tap(find.textContaining('Watch a short ad'));
      await tester.pumpAndSettle();
      expect(ads.shown, 1);
      expect(state.isUnlocked(series, 9), isTrue);
      expect(state.adsLeftToday, 2);
      expect(find.text('Episode 9 is locked'), findsNothing);
    });

    testWidgets('a skipped or missing ad unlocks nothing', (tester) async {
      final ads = ScriptedAds(AdOutcome.skipped);
      final state = await showSheet(tester, ads);
      final series = SampleData.seriesById('bride-price');
      await tester.tap(find.textContaining('Watch a short ad'));
      await tester.pumpAndSettle();
      expect(
        find.text('Watch the whole ad to unlock the episode.'),
        findsOneWidget,
      );

      ads.outcome = AdOutcome.unavailable;
      await tester.tap(find.textContaining('Watch a short ad'));
      await tester.pumpAndSettle();
      expect(
        find.text('No ad is available right now. Try again later.'),
        findsOneWidget,
      );
      expect(state.isUnlocked(series, 9), isFalse);
      expect(state.adsLeftToday, 3);
    });
  });
}
