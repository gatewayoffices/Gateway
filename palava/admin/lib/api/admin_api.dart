import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'rows.dart';

/// A problem to show the admin, in plain words.
class AdminException implements Exception {
  const AdminException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything the admin panel reads and writes. The database's security
/// rules check every change, so only accounts in `public.admins` can save.
abstract class AdminApi {
  String? get signedInEmail;

  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<bool> isAdmin();

  Future<List<SeriesRow>> listSeries();
  Future<void> createSeries(SeriesRow series);
  Future<void> updateSeries(SeriesRow series);
  Future<void> deleteSeries(String id);

  Future<List<EpisodeRow>> listEpisodes(String seriesId);

  /// Inserts or updates the episode and its video link and subtitles.
  Future<void> saveEpisode(EpisodeRow episode);
  Future<void> deleteEpisode(EpisodeRow episode);

  /// Adds [count] episodes after the last one, all using [videoUrl].
  Future<void> addEpisodes(
    String seriesId, {
    required int count,
    String? videoUrl,
    int? durationSeconds,
  });

  Future<Settings> getSettings();
  Future<void> saveSettings(Settings settings);

  Future<List<CoinPackRow>> listCoinPacks();
  Future<void> saveCoinPack(CoinPackRow pack);
  Future<void> deleteCoinPack(int id);

  Future<List<PassRow>> listPasses();
  Future<void> savePass(PassRow pass);
  Future<void> deletePass(String id);

  Future<List<HomeRowRow>> listHomeRows();
  Future<void> saveHomeRow(HomeRowRow row);
  Future<void> deleteHomeRow(int id);

  /// Newest first, unfinished ones at the top.
  Future<List<PurchaseRow>> listPurchases();

  /// Marks a test purchase paid: the viewer gets the coins or the pass.
  Future<void> confirmPurchase(int id);

  /// Marks an unfinished purchase as cancelled. Nothing is added.
  Future<void> cancelPurchase(int id);
}

class SupabaseAdminApi implements AdminApi {
  SupabaseAdminApi(this._client);

  final SupabaseClient _client;

  @override
  String? get signedInEmail => _client.auth.currentUser?.email;

  @override
  Future<void> signIn(String email, String password) => _guard(() async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthRetryableFetchException {
      rethrow;
    } on AuthException catch (e) {
      // Show Supabase's own reason too, so problems like an unconfirmed
      // account or a switched-off Email provider are easy to spot.
      final reason = e.message.toLowerCase();
      if (reason.contains('invalid login credentials')) {
        throw const AdminException(
          'Wrong email or password. (Supabase: Invalid login credentials)',
        );
      }
      if (reason.contains('not confirmed')) {
        throw const AdminException(
          'This account is not confirmed yet. In Supabase, delete the user '
          'and add it again with "Auto Confirm User" ticked.',
        );
      }
      throw AdminException('Could not sign in. (Supabase: ${e.message})');
    }
  });

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<bool> isAdmin() =>
      _guard(() async => await _client.rpc<bool>('is_admin') == true);

  // --- Series ----------------------------------------------------------------

  @override
  Future<List<SeriesRow>> listSeries() => _guard(() async {
    final rows = await _client
        .from('series')
        .select('*, episodes(count)')
        .order('title', ascending: true);
    return [for (final r in rows) SeriesRow.fromJson(r)];
  });

  @override
  Future<void> createSeries(SeriesRow series) => _guard(() async {
    try {
      await _client.from('series').insert(series.toJson());
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw AdminException(
          'A series with the id "${series.id}" already exists. '
          'Choose a different id.',
        );
      }
      rethrow;
    }
  });

  @override
  Future<void> updateSeries(SeriesRow series) => _guard(
    () => _client.from('series').update(series.toJson()).eq('id', series.id),
  );

  @override
  Future<void> deleteSeries(String id) =>
      _guard(() => _client.from('series').delete().eq('id', id));

  // --- Episodes --------------------------------------------------------------

  @override
  Future<List<EpisodeRow>> listEpisodes(String seriesId) => _guard(() async {
    final rows = await _client
        .from('episodes')
        .select('*, episode_media(video_url, subtitles_vtt)')
        .eq('series_id', seriesId)
        .order('number', ascending: true);
    return [for (final r in rows) EpisodeRow.fromJson(r)];
  });

  @override
  Future<void> saveEpisode(EpisodeRow episode) => _guard(() async {
    try {
      if (episode.id == null) {
        final row = await _client
            .from('episodes')
            .insert(episode.toJson())
            .select('id')
            .single();
        episode.id = row['id'] as int;
      } else {
        await _client
            .from('episodes')
            .update(episode.toJson())
            .eq('id', episode.id!);
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw AdminException(
          'Episode ${episode.number} already exists in this series.',
        );
      }
      rethrow;
    }
    final url = episode.videoUrl?.trim() ?? '';
    final media = _client.from('episode_media');
    if (url.isEmpty) {
      await media.delete().eq('episode_id', episode.id!);
    } else {
      await media.upsert({
        'episode_id': episode.id,
        'video_url': url,
        'subtitles_vtt': (episode.subtitlesVtt?.trim().isEmpty ?? true)
            ? null
            : episode.subtitlesVtt,
      });
    }
  });

  @override
  Future<void> deleteEpisode(EpisodeRow episode) =>
      _guard(() => _client.from('episodes').delete().eq('id', episode.id!));

  @override
  Future<void> addEpisodes(
    String seriesId, {
    required int count,
    String? videoUrl,
    int? durationSeconds,
  }) => _guard(() async {
    final last = await _client
        .from('episodes')
        .select('number')
        .eq('series_id', seriesId)
        .order('number', ascending: false)
        .limit(1)
        .maybeSingle();
    final start = (last?['number'] as int? ?? 0) + 1;
    final inserted = await _client
        .from('episodes')
        .insert([
          for (var n = start; n < start + count; n++)
            {
              'series_id': seriesId,
              'number': n,
              'duration_seconds': durationSeconds,
            },
        ])
        .select('id');
    final url = videoUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      await _client.from('episode_media').insert([
        for (final row in inserted) {'episode_id': row['id'], 'video_url': url},
      ]);
    }
  });

  // --- Settings --------------------------------------------------------------

  @override
  Future<Settings> getSettings() => _guard(() async {
    final row = await _client.from('app_settings').select().single();
    return Settings.fromJson(row);
  });

  @override
  Future<void> saveSettings(Settings settings) => _guard(
    () => _client.from('app_settings').update(settings.toJson()).eq('id', true),
  );

  // --- Store -----------------------------------------------------------------

  @override
  Future<List<CoinPackRow>> listCoinPacks() => _guard(() async {
    final rows = await _client
        .from('coin_packs')
        .select()
        .order('position', ascending: true);
    return [for (final r in rows) CoinPackRow.fromJson(r)];
  });

  @override
  Future<void> saveCoinPack(CoinPackRow pack) => _guard(() async {
    final table = _client.from('coin_packs');
    if (pack.id == null) {
      final row = await table.insert(pack.toJson()).select('id').single();
      pack.id = row['id'] as int;
    } else {
      await table.update(pack.toJson()).eq('id', pack.id!);
    }
  });

  @override
  Future<void> deleteCoinPack(int id) =>
      _guard(() => _client.from('coin_packs').delete().eq('id', id));

  @override
  Future<List<PassRow>> listPasses() => _guard(() async {
    final rows = await _client
        .from('passes')
        .select()
        .order('position', ascending: true);
    return [for (final r in rows) PassRow.fromJson(r)];
  });

  @override
  Future<void> savePass(PassRow pass) =>
      _guard(() => _client.from('passes').upsert(pass.toJson()));

  @override
  Future<void> deletePass(String id) =>
      _guard(() => _client.from('passes').delete().eq('id', id));

  // --- Home rows -------------------------------------------------------------

  @override
  Future<List<HomeRowRow>> listHomeRows() => _guard(() async {
    final rows = await _client
        .from('home_rows')
        .select()
        .order('position', ascending: true);
    return [for (final r in rows) HomeRowRow.fromJson(r)];
  });

  @override
  Future<void> saveHomeRow(HomeRowRow row) => _guard(() async {
    final table = _client.from('home_rows');
    if (row.id == null) {
      final saved = await table.insert(row.toJson()).select('id').single();
      row.id = saved['id'] as int;
    } else {
      await table.update(row.toJson()).eq('id', row.id!);
    }
  });

  @override
  Future<void> deleteHomeRow(int id) =>
      _guard(() => _client.from('home_rows').delete().eq('id', id));

  // --- Purchases -------------------------------------------------------------

  @override
  Future<List<PurchaseRow>> listPurchases() => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>('admin_list_purchases');
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        PurchaseRow.fromJson(r),
    ];
  });

  @override
  Future<void> confirmPurchase(int id) => _guard(
    () => _client.rpc<void>(
      'admin_confirm_purchase',
      params: {'p_purchase_id': id},
    ),
  );

  @override
  Future<void> cancelPurchase(int id) => _guard(
    () => _client.rpc<void>(
      'admin_cancel_purchase',
      params: {'p_purchase_id': id},
    ),
  );

  /// Turns server and network errors into messages for the admin.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AdminException {
      rethrow;
    } on PostgrestException catch (e) {
      throw AdminException(switch (e.code) {
        '42501' =>
          'This account is not allowed to make changes. '
              'Ask for it to be added as an admin.',
        '23503' => 'That is still used somewhere else, so it cannot change.',
        '23514' => 'One of the values is not allowed (${e.message}).',
        _ => 'The server refused the change: ${e.message}',
      });
    } on AuthRetryableFetchException {
      throw const AdminException(
        'Could not reach Supabase. Check the connection.',
      );
    } on AuthException catch (e) {
      throw AdminException(e.message);
    } on TimeoutException {
      throw const AdminException(
        'Supabase took too long to answer. Try again.',
      );
    } on ClientException {
      throw const AdminException(
        'Could not reach Supabase. Check the connection.',
      );
    }
  }
}
