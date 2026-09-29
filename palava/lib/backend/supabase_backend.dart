import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:http/http.dart' show ClientException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models.dart';
import '../playback/watch_history.dart';
import 'backend.dart';
import 'backend_config.dart';

/// Where Google sign-in returns to the app. Must also be listed in Supabase
/// under Authentication > URL Configuration > Redirect URLs, and matches the
/// intent filter in AndroidManifest.xml.
const authRedirectUrl = 'com.palava.palava://login-callback';

/// The real backend: Supabase (see supabase/migrations for the database).
class SupabaseBackend implements Backend {
  SupabaseBackend._(this._client, this._prefs, this._config);

  static Future<SupabaseBackend> connect(
    BackendConfig config,
    SharedPreferences prefs,
  ) async {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseKey,
    );
    return SupabaseBackend._(Supabase.instance.client, prefs, config);
  }

  /// For tests that talk to a local copy of the database.
  @visibleForTesting
  SupabaseBackend.withClient(
    SupabaseClient client,
    SharedPreferences prefs,
    BackendConfig config,
  ) : this._(client, prefs, config);

  static const _catalogKey = 'catalog_cache_v1';

  final SupabaseClient _client;
  final SharedPreferences _prefs;
  final BackendConfig _config;

  @override
  bool get isSample => false;

  @override
  bool get supportsGoogle => _config.googleSignIn;

  @override
  Catalog? get cachedCatalog {
    final raw = _prefs.getString(_catalogKey);
    if (raw == null) return null;
    try {
      return Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null; // Saved by an older version: fetch a fresh one.
    }
  }

  @override
  Future<Catalog> loadCatalog() => _guard(() async {
    final results = await Future.wait([
      _client.from('app_settings').select().single(),
      _client.from('series_catalog').select().order('title', ascending: true),
      _client.from('coin_packs').select().order('position', ascending: true),
      _client.from('passes').select().order('position', ascending: true),
      _client.from('home_rows').select().order('position', ascending: true),
    ]);
    final settings = results[0] as Map<String, dynamic>;
    List<Map<String, dynamic>> rows(int i) =>
        (results[i] as List).cast<Map<String, dynamic>>();

    final catalog = Catalog(
      series: [for (final s in rows(1)) Series.fromJson(s)],
      featuredSeriesId: settings['featured_series_id'] as String?,
      forYouSeriesIds: List<String>.from(
        settings['for_you_series_ids'] as List? ?? const [],
      ),
      config: AppConfig(
        freeEpisodeCount: settings['free_episode_count'] as int,
        unlockCostCoins: settings['unlock_cost_coins'] as int,
        freeAdsPerDay: settings['free_ads_per_day'] as int,
        dataSaverMaxBitrate: settings['data_saver_max_bitrate'] as int,
        priceLabel: settings['price_label'] as String,
        paymentMode: PaymentMode.parse(settings['payment_mode'] as String?),
        coinPacks: [for (final p in rows(2)) CoinPack.fromJson(p)],
        passes: [for (final p in rows(3)) Pass.fromJson(p)],
        homeRows: [for (final r in rows(4)) HomeRow.fromJson(r)],
      ),
    );
    await _prefs.setString(_catalogKey, jsonEncode(catalog.toJson()));
    return catalog;
  });

  @override
  Future<Episode> loadEpisode(Series series, int number) => _guard(() async {
    final row = await _client
        .from('episodes')
        .select(
          'number, duration_seconds, episode_media(video_url, subtitles_vtt)',
        )
        .eq('series_id', series.id)
        .eq('number', number)
        .maybeSingle();
    if (row == null) {
      return Episode(seriesId: series.id, number: number);
    }
    // Empty when the security rules hide a locked episode's link.
    final media = switch (row['episode_media']) {
      final Map<String, dynamic> m => m,
      [final Map<String, dynamic> m, ...] => m,
      _ => null,
    };
    final seconds = row['duration_seconds'] as int?;
    return Episode(
      seriesId: series.id,
      number: number,
      videoUrl: media?['video_url'] as String?,
      subtitlesVtt: media?['subtitles_vtt'] as String?,
      endsAt: seconds == null ? null : Duration(seconds: seconds),
    );
  });

  @override
  BackendUser? get currentUser => _toUser(_client.auth.currentUser);

  @override
  Stream<BackendUser?> get userChanges => _client.auth.onAuthStateChange
      .where(
        (s) =>
            s.event == AuthChangeEvent.signedIn ||
            s.event == AuthChangeEvent.signedOut ||
            s.event == AuthChangeEvent.initialSession,
      )
      .map((s) => _toUser(s.session?.user));

  static BackendUser? _toUser(User? user) => user == null
      ? null
      : BackendUser(
          id: user.id,
          phone: user.phone,
          email: user.email,
          name:
              user.userMetadata?['full_name'] as String? ??
              user.userMetadata?['name'] as String?,
        );

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const BackendException(BackendErrorKind.signInRequired);
    }
    return id;
  }

  @override
  Future<void> sendPhoneCode(String phone) =>
      _guard(() => _client.auth.signInWithOtp(phone: phone));

  @override
  Future<void> verifyPhoneCode(String phone, String code) => _guard(() async {
    try {
      await _client.auth.verifyOTP(
        type: OtpType.sms,
        phone: phone,
        token: code,
      );
    } on AuthException catch (e) {
      throw BackendException(BackendErrorKind.invalidCode, e.message);
    }
  });

  @override
  Future<void> signInWithGoogle() => _guard(
    () => _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: authRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    ),
  );

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<ViewerData> loadViewer() => _guard(() async {
    final userId = _userId;
    final results = await Future.wait<Object?>([
      _client.from('wallets').select('balance').maybeSingle(),
      _client.rpc<int>('ads_left_today'),
      _client.from('episode_unlocks').select('episodes(series_id, number)'),
      _client.from('my_list').select('series_id'),
      _client.from('series_likes').select('series_id'),
      _client.from('watch_history').select(),
      _client
          .from('profiles')
          .select('display_name, phone')
          .eq('id', userId)
          .maybeSingle(),
      _client.rpc<bool>('has_active_pass'),
      _client
          .from('user_passes')
          .select('ends_at')
          .gt('ends_at', DateTime.now().toUtc().toIso8601String())
          .order('ends_at', ascending: false)
          .limit(1),
      _client
          .from('purchases')
          .select('reference, product_name, status, created_at')
          .order('created_at', ascending: false)
          .limit(5),
    ]);
    List<Map<String, dynamic>> rows(int i) =>
        (results[i] as List).cast<Map<String, dynamic>>();

    final unlocked = <String, Set<int>>{};
    for (final row in rows(2)) {
      final episode = row['episodes'] as Map<String, dynamic>?;
      if (episode == null) continue;
      unlocked
          .putIfAbsent(episode['series_id'] as String, () => {})
          .add(episode['number'] as int);
    }
    final profile = results[6] as Map<String, dynamic>?;
    return ViewerData(
      coinBalance:
          (results[0] as Map<String, dynamic>?)?['balance'] as int? ?? 0,
      adsLeftToday: results[1] as int? ?? 0,
      unlocked: unlocked,
      myList: {for (final r in rows(3)) r['series_id'] as String},
      liked: {for (final r in rows(4)) r['series_id'] as String},
      history: [
        for (final r in rows(5))
          WatchEntry(
            seriesId: r['series_id'] as String,
            episodeNumber: r['episode_number'] as int,
            position: Duration(milliseconds: r['position_ms'] as int),
            duration: Duration(milliseconds: r['duration_ms'] as int),
            updatedAt: DateTime.parse(r['updated_at'] as String),
          ),
      ],
      displayName: profile?['display_name'] as String?,
      phone: profile?['phone'] as String?,
      hasActivePass: results[7] as bool? ?? false,
      passEndsAt: switch (rows(8)) {
        [final row, ...] => DateTime.parse(row['ends_at'] as String).toLocal(),
        _ => null,
      },
      recentPurchases: [
        for (final r in rows(9))
          if (r['reference'] != null)
            PurchaseSummary(
              reference: r['reference'] as String,
              productName: r['product_name'] as String? ?? '',
              status: PurchaseStatus.values.firstWhere(
                (s) => s.name == r['status'],
                orElse: () => PurchaseStatus.pending,
              ),
              createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            ),
      ],
    );
  });

  @override
  Future<PurchaseTicket> startPurchase({
    int? coinPackId,
    String? passId,
    required String paymentMethod,
  }) => _guard(() async {
    final result = await _client.rpc<Map<String, dynamic>>(
      'start_purchase',
      params: {
        'p_coin_pack_id': coinPackId,
        'p_pass_id': passId,
        'p_payment_method': paymentMethod,
      },
    );
    return PurchaseTicket(
      id: result['id'] as int,
      reference: result['reference'] as String,
    );
  });

  @override
  Future<int> unlockWithCoins(Series series, int episodeNumber) => _guard(
    () => _client.rpc<int>(
      'unlock_episode_with_coins',
      params: {'p_series_id': series.id, 'p_episode_number': episodeNumber},
    ),
  );

  @override
  Future<int> unlockWithAd(Series series, int episodeNumber) => _guard(
    () => _client.rpc<int>(
      'unlock_episode_with_ad',
      params: {'p_series_id': series.id, 'p_episode_number': episodeNumber},
    ),
  );

  @override
  Future<void> setInMyList(String seriesId, bool inList) => _guard(() async {
    final table = _client.from('my_list');
    if (inList) {
      await table.upsert({'user_id': _userId, 'series_id': seriesId});
    } else {
      await table.delete().eq('user_id', _userId).eq('series_id', seriesId);
    }
  });

  @override
  Future<void> setLiked(String seriesId, bool liked) => _guard(() async {
    final table = _client.from('series_likes');
    if (liked) {
      await table.upsert({'user_id': _userId, 'series_id': seriesId});
    } else {
      await table.delete().eq('user_id', _userId).eq('series_id', seriesId);
    }
  });

  @override
  Future<void> saveProgress(WatchEntry entry) => _guard(
    () => _client.from('watch_history').upsert({
      'user_id': _userId,
      'series_id': entry.seriesId,
      'episode_number': entry.episodeNumber,
      'position_ms': entry.position.inMilliseconds,
      'duration_ms': entry.duration.inMilliseconds,
      'updated_at': entry.updatedAt.toUtc().toIso8601String(),
    }),
  );

  @override
  Future<void> updateProfile({String? language, List<String>? genres}) =>
      _guard(() async {
        final changes = {'language': ?language, 'favourite_genres': ?genres};
        if (changes.isEmpty) return;
        await _client.from('profiles').update(changes).eq('id', _userId);
      });

  /// Turns network and server errors into [BackendException]s, and logs
  /// them so the reason shows in the `flutter run` window.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await _translate(action);
    } on BackendException catch (e) {
      debugPrint('Palava backend error: ${e.kind.name}: ${e.detail}');
      rethrow;
    }
  }

  static Future<T> _translate<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on BackendException {
      rethrow;
    } on PostgrestException catch (e) {
      throw BackendException(switch ((e.hint, e.code)) {
        ('insufficient_coins', _) => BackendErrorKind.notEnoughCoins,
        ('no_ads_left', _) => BackendErrorKind.noAdsLeft,
        ('payments_off', _) => BackendErrorKind.paymentsOff,
        ('too_many_pending', _) => BackendErrorKind.tooManyPending,
        (_, '28000' || '42501') => BackendErrorKind.signInRequired,
        _ => BackendErrorKind.unknown,
      }, e.message);
    } on AuthRetryableFetchException catch (e) {
      throw BackendException(BackendErrorKind.offline, e.message);
    } on AuthException catch (e) {
      throw BackendException(BackendErrorKind.unknown, e.message);
    } on SocketException catch (e) {
      throw BackendException(BackendErrorKind.offline, e.message);
    } on TimeoutException catch (e) {
      throw BackendException(BackendErrorKind.offline, e.message);
    } on ClientException catch (e) {
      throw BackendException(BackendErrorKind.offline, e.message);
    } on Object catch (e) {
      // Anything unexpected (e.g. data in a shape the app does not know).
      throw BackendException(BackendErrorKind.unknown, e.toString());
    }
  }
}
