import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:palava/data/sample_data.dart';
import 'package:palava/main.dart';
import 'package:palava/screens/series_screen.dart';
import 'package:palava/state/app_state.dart';

void main() {
  setUp(() {
    // A typical small Android phone.
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

  testWidgets('guest can reach every tab', (tester) async {
    await tester.pumpWidget(PalavaApp(state: AppState()));
    await tester.scrollUntilVisible(find.text('Browse as a guest'), 200);
    expect(find.text('Send me a code'), findsOneWidget);
    expect(find.text('+231'), findsOneWidget);

    await tester.tap(find.text('Browse as a guest'));
    await tester.pumpAndSettle();
    expect(find.text('Continue watching'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Trending in Monrovia'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Trending in Monrovia'), findsOneWidget);

    await tester.tap(find.text('For You'));
    await tester.pumpAndSettle();
    expect(find.text('Watch all episodes'), findsWidgets);

    await tester.tap(find.text('My List').last);
    await tester.pumpAndSettle();
    expect(find.text('Waterside Boys'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Data saver'), findsOneWidget);
    expect(find.text('Download on WiFi only'), findsOneWidget);

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(find.text('[PRICE]'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('MTN Mobile Money'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('MTN Mobile Money'), findsOneWidget);
    expect(find.text('[PRICE]'), findsWidgets);
  });

  testWidgets('locked episode unlocks with coins', (tester) async {
    final state = AppState();
    final series = SampleData.seriesById('bride-price');
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: MaterialApp(home: SeriesScreen(series: series)),
      ),
    );

    expect(state.isUnlocked(series.id, 8), isTrue);
    expect(state.isUnlocked(series.id, 9), isFalse);

    await tester.scrollUntilVisible(find.text('9'), 200);
    await tester.ensureVisible(find.text('9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9'));
    await tester.pumpAndSettle();
    expect(find.text('Episode 9 is locked'), findsOneWidget);

    final before = state.coinBalance;
    await tester.tap(find.text('Unlock with 30 coins'));
    await tester.pumpAndSettle();
    expect(state.isUnlocked(series.id, 9), isTrue);
    expect(state.coinBalance, before - 30);
  });
}
