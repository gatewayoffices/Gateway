import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palava_admin/app.dart';

import 'fake_admin_api.dart';

void main() {
  setUp(() {
    // A tall window, so long forms are fully built without scrolling.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1440, 2200);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> signIn(WidgetTester tester, FakeAdminApi api) async {
    await tester.pumpWidget(AdminApp(api: api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'me@palava.app');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
  }

  testWidgets('wrong passwords and non-admins are kept out', (tester) async {
    final api = FakeAdminApi(admin: false);
    await tester.pumpWidget(AdminApp(api: api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'me@palava.app');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(find.text('Wrong email or password.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(find.text('This account is not an admin'), findsOneWidget);
    expect(find.text('New series'), findsNothing);
  });

  testWidgets('create a series and add its episodes', (tester) async {
    final api = FakeAdminApi();
    await signIn(tester, api);
    expect(find.text('Waterside Boys'), findsOneWidget);

    await tester.tap(find.text('New series'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      "Mama Sia's Kitchen",
    );
    await tester.pump();
    // The id follows the title.
    expect(find.text('mama-sias-kitchen'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Genres'),
      'Comedy, Family',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Free episodes'),
      '5',
    );
    await tester.tap(find.text('Create series'));
    await tester.pumpAndSettle();

    final created = api.series.last;
    expect(created.id, 'mama-sias-kitchen');
    expect(created.genres, ['Comedy', 'Family']);
    expect(created.freeEpisodeCount, 5);
    expect(created.unlockCostCoins, isNull);
    expect(created.published, isFalse);

    // Episodes can now be added.
    await tester.tap(find.text('Add episodes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'How many'), '3');
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Video link for all of them (optional)',
      ),
      'https://example.com/test.m3u8',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(api.episodes.map((e) => e.number), [1, 2, 3]);
    expect(find.text('Episodes (3)'), findsOneWidget);

    // Edit episode 2: a bad link is refused, a good one is saved.
    await tester.tap(find.text('Episode 2'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Video link (.m3u8)'),
      'http://insecure.example.com/a.m3u8',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Must start with https://'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Video link (.m3u8)'),
      'https://example.com/two.m3u8',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title (optional)'),
      'The cookshop fire',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.episodes[1].videoUrl, 'https://example.com/two.m3u8');
    expect(find.text('The cookshop fire'), findsOneWidget);
  });

  testWidgets('settings save and the For You list can be edited', (
    tester,
  ) async {
    final api = FakeAdminApi();
    await signIn(tester, api);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Coins to unlock an episode'),
      '20',
    );
    await tester.tap(find.text('Add a series'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Waterside Boys').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();

    expect(api.settings.unlockCostCoins, 20);
    expect(api.settings.forYouSeriesIds, ['waterside']);
    expect(api.settings.dataSaverMaxBitrate, 800000);
  });

  testWidgets('add a coin pack and a home row', (tester) async {
    final api = FakeAdminApi();
    await signIn(tester, api);

    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add pack'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Coins'), '250');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price label'),
      'USD 2.49',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.packs.last.coins, 250);
    expect(find.text('250 coins'), findsOneWidget);

    await tester.tap(find.text('Home rows'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New row'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Trending in Monrovia',
    );
    await tester.tap(find.text('Add a series'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Waterside Boys').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.homeRows.single.seriesIds, ['waterside']);
    expect(find.text('Trending in Monrovia'), findsOneWidget);
  });

  testWidgets('every page fits a small laptop screen', (tester) async {
    _smallScreen();
    final api = FakeAdminApi();
    await api.addEpisodes('waterside', count: 12);
    await signIn(tester, api);
    for (final page in ['Settings', 'Store', 'Home rows', 'Series']) {
      await tester.tap(find.text(page).first);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Waterside Boys'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('New series').evaluate().isEmpty
          ? find.byTooltip('Back')
          : find.text('New series'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

void _smallScreen() {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view.physicalSize = const Size(1280, 720);
  view.devicePixelRatio = 1;
}
