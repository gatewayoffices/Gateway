// Runs the admin panel's database code against a local copy of the database
// served by PostgREST (the server Supabase uses). Skipped unless
// supabase/tests/run_api_tests.sh starts that server and sets PALAVA_TEST_*.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:palava_admin/api/admin_api.dart';
import 'package:palava_admin/api/rows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final env = Platform.environment;
  final url = env['PALAVA_TEST_API_URL'];
  final skip = url == null
      ? 'Needs the local API from supabase/tests/run_api_tests.sh'
      : null;

  Future<SupabaseAdminApi> signedInAs(String jwtKey, String idKey) async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(
      url!,
      env['PALAVA_TEST_ANON_KEY']!,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': env[jwtKey],
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'unused',
        'user': {
          'id': env[idKey],
          'aud': 'authenticated',
          'email': 'admin@example.com',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': DateTime.now().toIso8601String(),
        },
      }),
    );
    return SupabaseAdminApi(client);
  }

  test('a viewer is not an admin and cannot change anything', () async {
    final api = await signedInAs('PALAVA_TEST_USER_JWT', 'PALAVA_TEST_USER_ID');
    expect(await api.isAdmin(), isFalse);
    await expectLater(api.listPurchases(), throwsA(isA<AdminException>()));
    await expectLater(api.confirmPurchase(1), throwsA(isA<AdminException>()));
    await expectLater(
      api.createSeries(SeriesRow(id: 'nope', title: 'Nope')),
      throwsA(
        isA<AdminException>().having(
          (e) => e.message,
          'message',
          contains('not allowed'),
        ),
      ),
    );
    final settings = await api.getSettings();
    settings.unlockCostCoins = 1;
    await api.saveSettings(settings);
    expect((await api.getSettings()).unlockCostCoins, 30);
  }, skip: skip);

  test('an admin manages series, episodes, settings and the store', () async {
    final api = await signedInAs(
      'PALAVA_TEST_ADMIN_JWT',
      'PALAVA_TEST_ADMIN_ID',
    );
    expect(await api.isAdmin(), isTrue);

    // Series list includes episode counts.
    var series = await api.listSeries();
    expect(series, hasLength(8));
    expect(series.firstWhere((s) => s.id == 'bride-price').episodeCount, 40);

    // Create a draft series.
    final draft = SeriesRow(
      id: SeriesRow.slugFor("Mama's New Show!"),
      title: "Mama's New Show!",
      genres: ['Comedy'],
      freeEpisodeCount: 3,
      unlockCostCoins: 20,
    );
    expect(draft.id, 'mamas-new-show');
    await api.createSeries(draft);
    await expectLater(
      api.createSeries(draft),
      throwsA(isA<AdminException>()),
      reason: 'duplicate ids are refused',
    );

    // Episodes: bulk add, then edit one with subtitles, then remove one.
    await api.addEpisodes(
      draft.id,
      count: 3,
      videoUrl: 'https://example.com/a.m3u8',
      durationSeconds: 90,
    );
    var episodes = await api.listEpisodes(draft.id);
    expect(episodes.map((e) => e.number), [1, 2, 3]);
    expect(episodes.first.videoUrl, 'https://example.com/a.m3u8');

    final second = episodes[1]
      ..title = 'The letter'
      ..videoUrl = 'https://example.com/b.m3u8'
      ..subtitlesVtt = 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello';
    await api.saveEpisode(second);
    await api.addEpisodes(draft.id, count: 1);
    await api.saveEpisode(EpisodeRow(seriesId: draft.id, number: 5));
    episodes = await api.listEpisodes(draft.id);
    expect(episodes.map((e) => e.number), [1, 2, 3, 4, 5]);
    expect(episodes[1].title, 'The letter');
    expect(episodes[1].videoUrl, 'https://example.com/b.m3u8');
    expect(episodes[1].subtitlesVtt, startsWith('WEBVTT'));
    expect(episodes[3].videoUrl, isNull);

    // Clearing the link removes it.
    await api.saveEpisode(episodes[0]..videoUrl = '');
    await api.deleteEpisode(episodes[4]);
    episodes = await api.listEpisodes(draft.id);
    expect(episodes, hasLength(4));
    expect(episodes.first.videoUrl, isNull);

    // Publish and edit the series.
    await api.updateSeries(
      draft
        ..published = true
        ..tagline = 'Big laughs',
    );
    series = await api.listSeries();
    final saved = series.firstWhere((s) => s.id == draft.id);
    expect(saved.published, isTrue);
    expect(saved.tagline, 'Big laughs');
    expect(saved.episodeCount, 4);
    expect(saved.freeEpisodeCount, 3);

    // Settings.
    final settings = await api.getSettings();
    expect(settings.priceLabel, '[PRICE]');
    settings
      ..unlockCostCoins = 25
      ..featuredSeriesId = draft.id
      ..forYouSeriesIds = [draft.id, 'waterside'];
    await api.saveSettings(settings);
    final reloaded = await api.getSettings();
    expect(reloaded.unlockCostCoins, 25);
    expect(reloaded.featuredSeriesId, draft.id);
    expect(reloaded.forYouSeriesIds, [draft.id, 'waterside']);

    // Store and home rows.
    final pack = CoinPackRow(coins: 50, position: 9, priceLabel: 'USD 0.50');
    await api.saveCoinPack(pack);
    expect(pack.id, isNotNull);
    await api.saveCoinPack(pack..bonusCoins = 5);
    expect((await api.listCoinPacks()).last.bonusCoins, 5);
    await api.deleteCoinPack(pack.id!);
    expect(await api.listCoinPacks(), hasLength(4));

    await api.savePass(
      PassRow(id: 'month', name: 'Month pass', durationHours: 720, position: 2),
    );
    expect((await api.listPasses()).map((p) => p.id), ['day', 'week', 'month']);
    await api.deletePass('month');

    final row = HomeRowRow(title: 'Laughs', position: 5, seriesIds: [draft.id]);
    await api.saveHomeRow(row);
    await api.saveHomeRow(row..title = 'Big laughs');
    expect((await api.listHomeRows()).last.title, 'Big laughs');
    await api.deleteHomeRow(row.id!);

    // Purchases: a viewer starts two, the admin confirms one and cancels one.
    final viewer = SupabaseClient(
      url!,
      env['PALAVA_TEST_ANON_KEY']!,
      accessToken: () async => env['PALAVA_TEST_USER_JWT'],
    );
    final bought = await viewer.rpc<Map<String, dynamic>>(
      'start_purchase',
      params: {'p_pass_id': 'week', 'p_payment_method': 'card'},
    );
    final dropped = await viewer.rpc<Map<String, dynamic>>(
      'start_purchase',
      params: {'p_pass_id': 'day'},
    );
    var purchases = await api.listPurchases();
    final mine = purchases.firstWhere((p) => p.id == bought['id']);
    expect(mine.isPending && mine.canConfirm, isTrue);
    expect(mine.productName, 'Week pass');
    expect(mine.viewer, '231770000009');
    expect(mine.paymentMethod, 'card');
    await api.confirmPurchase(bought['id'] as int);
    await api.cancelPurchase(dropped['id'] as int);
    purchases = await api.listPurchases();
    expect(purchases.firstWhere((p) => p.id == bought['id']).status, 'paid');
    expect(purchases.firstWhere((p) => p.id == dropped['id']).status, 'failed');

    final settingsNow = await api.getSettings();
    expect(settingsNow.paymentMode, 'test');
    await api.saveSettings(settingsNow..paymentMode = 'off');
    expect((await api.getSettings()).paymentMode, 'off');
    await api.saveSettings(settingsNow..paymentMode = 'test');

    // Deleting the series removes its episodes too.
    await api.deleteSeries(draft.id);
    expect(await api.listEpisodes(draft.id), isEmpty);
    expect((await api.getSettings()).featuredSeriesId, isNull);
  }, skip: skip);
}
