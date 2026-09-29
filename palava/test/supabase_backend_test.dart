// Talks to a local copy of the database through PostgREST, the same server
// Supabase runs. Skipped unless supabase/tests/run_api_tests.sh starts that
// server and sets the PALAVA_TEST_* variables.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:palava/backend/backend.dart';
import 'package:palava/backend/backend_config.dart';
import 'package:palava/backend/supabase_backend.dart';
import 'package:palava/playback/watch_history.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final env = Platform.environment;
  final url = env['PALAVA_TEST_API_URL'];
  final skip = url == null
      ? 'Needs the local API from supabase/tests/run_api_tests.sh'
      : null;

  late SupabaseClient client;
  late SupabaseBackend backend;

  setUpAll(() async {
    if (url == null) return;
    SharedPreferences.setMockInitialValues({});
    const config = BackendConfig(
      supabaseUrl: 'unused',
      supabaseKey: 'unused',
      googleSignIn: false,
    );
    client = SupabaseClient(
      url,
      env['PALAVA_TEST_ANON_KEY']!,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    backend = SupabaseBackend.withClient(
      client,
      await SharedPreferences.getInstance(),
      config,
    );
  });

  Future<void> signIn() => client.auth.recoverSession(
    jsonEncode({
      'access_token': env['PALAVA_TEST_USER_JWT'],
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'unused',
      'user': {
        'id': env['PALAVA_TEST_USER_ID'],
        'aud': 'authenticated',
        'phone': '231770000009',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': DateTime.now().toIso8601String(),
      },
    }),
  );

  test('guests get the catalog and it is saved on the phone', () async {
    expect(backend.cachedCatalog, isNull);
    final catalog = await backend.loadCatalog();
    expect(catalog.series, hasLength(8));
    expect(catalog.featured?.id, 'bride-price');
    expect(catalog.forYou, hasLength(6));
    expect(catalog.config.homeRows, hasLength(3));
    expect(catalog.config.coinPacks.map((p) => p.coins), [100, 300, 600, 1200]);
    expect(catalog.config.passes.map((p) => p.id), ['day', 'week']);
    expect(catalog.config.freeEpisodeCount, 8);
    expect(catalog.seriesById('bride-price')!.episodeCount, 40);
    expect(backend.cachedCatalog?.series, hasLength(8));
  }, skip: skip);

  test('guests get video links for free episodes only', () async {
    final series = (await backend.loadCatalog()).seriesById('bride-price')!;
    final free = await backend.loadEpisode(series, 1);
    expect(free.isPlayable, isTrue);
    expect(free.videoUrl, endsWith('.m3u8'));
    expect(free.subtitlesVtt, startsWith('WEBVTT'));
    expect(free.endsAt, const Duration(seconds: 75));

    final locked = await backend.loadEpisode(series, 9);
    expect(locked.isPlayable, isFalse);
    expect(locked.endsAt, const Duration(seconds: 75));
  }, skip: skip);

  test('guests cannot unlock', () async {
    final series = (await backend.loadCatalog()).seriesById('bride-price')!;
    await expectLater(
      backend.unlockWithCoins(series, 9),
      throwsA(
        isA<BackendException>().having(
          (e) => e.kind,
          'kind',
          BackendErrorKind.signInRequired,
        ),
      ),
    );
  }, skip: skip);

  test('a signed-in viewer unlocks, saves lists and history', () async {
    await signIn();
    expect(backend.currentUser?.id, env['PALAVA_TEST_USER_ID']);
    final catalog = await backend.loadCatalog();
    final bridePrice = catalog.seriesById('bride-price')!;
    final waterside = catalog.seriesById('waterside')!;

    var viewer = await backend.loadViewer();
    expect(viewer.coinBalance, 45);
    expect(viewer.adsLeftToday, 3);
    expect(viewer.unlocked, isEmpty);
    expect(viewer.phone, '231770000009');

    expect(await backend.unlockWithCoins(bridePrice, 9), 15);
    expect((await backend.loadEpisode(bridePrice, 9)).isPlayable, isTrue);
    await expectLater(
      backend.unlockWithCoins(bridePrice, 10),
      throwsA(
        isA<BackendException>().having(
          (e) => e.kind,
          'kind',
          BackendErrorKind.notEnoughCoins,
        ),
      ),
    );
    expect(await backend.unlockWithAd(waterside, 9), 2);

    await backend.setInMyList('waterside', true);
    await backend.setInMyList('palm-wine', true);
    await backend.setInMyList('palm-wine', false);
    await backend.setLiked('sinkor-nights', true);
    final watched = DateTime.utc(2026, 9, 29, 12);
    await backend.saveProgress(
      WatchEntry(
        seriesId: 'waterside',
        episodeNumber: 4,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 75),
        updatedAt: watched,
      ),
    );
    // Saving again updates the same row.
    await backend.saveProgress(
      WatchEntry(
        seriesId: 'waterside',
        episodeNumber: 5,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 75),
        updatedAt: watched,
      ),
    );
    await backend.updateProfile(language: 'fr', genres: ['Drama']);

    viewer = await backend.loadViewer();
    expect(viewer.coinBalance, 15);
    expect(viewer.adsLeftToday, 2);
    expect(viewer.unlocked, {
      'bride-price': {9},
      'waterside': {9},
    });
    expect(viewer.myList, {'waterside'});
    expect(viewer.liked, {'sinkor-nights'});
    expect(viewer.history.single.episodeNumber, 5);
    expect(viewer.history.single.position, const Duration(seconds: 10));
    expect(viewer.history.single.updatedAt, watched);
    expect(viewer.hasActivePass, isFalse);
  }, skip: skip);
}
