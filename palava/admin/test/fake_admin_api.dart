import 'package:palava_admin/api/admin_api.dart';
import 'package:palava_admin/api/rows.dart';

/// Keeps everything in memory so screens can be tested without a server.
class FakeAdminApi implements AdminApi {
  FakeAdminApi({this.admin = true});

  bool admin;
  String? _email;
  final series = <SeriesRow>[
    SeriesRow(id: 'waterside', title: 'Waterside Boys', published: true),
  ];
  final episodes = <EpisodeRow>[];
  var settings = Settings(
    freeEpisodeCount: 8,
    unlockCostCoins: 30,
    freeAdsPerDay: 3,
    welcomeCoins: 45,
    dataSaverMaxBitrate: 800000,
    priceLabel: '[PRICE]',
  );
  final packs = <CoinPackRow>[CoinPackRow(id: 1, coins: 100)];
  final passes = <PassRow>[
    PassRow(id: 'day', name: 'Day pass', durationHours: 24),
  ];
  final homeRows = <HomeRowRow>[];
  int _nextId = 100;

  @override
  String? get signedInEmail => _email;

  @override
  Future<void> signIn(String email, String password) async {
    if (password != 'secret') {
      throw const AdminException('Wrong email or password.');
    }
    _email = email;
  }

  @override
  Future<void> signOut() async => _email = null;

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<List<SeriesRow>> listSeries() async => [
    for (final s in series)
      s..episodeCount = episodes.where((e) => e.seriesId == s.id).length,
  ];

  @override
  Future<void> createSeries(SeriesRow row) async {
    if (series.any((s) => s.id == row.id)) {
      throw const AdminException('A series with that id already exists.');
    }
    series.add(row);
  }

  @override
  Future<void> updateSeries(SeriesRow row) async {}

  @override
  Future<void> deleteSeries(String id) async {
    series.removeWhere((s) => s.id == id);
    episodes.removeWhere((e) => e.seriesId == id);
  }

  @override
  Future<List<EpisodeRow>> listEpisodes(String seriesId) async =>
      episodes.where((e) => e.seriesId == seriesId).toList()
        ..sort((a, b) => a.number.compareTo(b.number));

  @override
  Future<void> saveEpisode(EpisodeRow episode) async {
    if (episode.id == null) {
      episode.id = _nextId++;
      episodes.add(episode);
    }
    if (episode.videoUrl?.trim().isEmpty ?? false) episode.videoUrl = null;
    if (episode.subtitlesVtt?.trim().isEmpty ?? false) {
      episode.subtitlesVtt = null;
    }
  }

  @override
  Future<void> deleteEpisode(EpisodeRow episode) async =>
      episodes.remove(episode);

  @override
  Future<void> addEpisodes(
    String seriesId, {
    required int count,
    String? videoUrl,
    int? durationSeconds,
  }) async {
    final existing = await listEpisodes(seriesId);
    final start = existing.isEmpty ? 1 : existing.last.number + 1;
    for (var n = start; n < start + count; n++) {
      episodes.add(
        EpisodeRow(
          id: _nextId++,
          seriesId: seriesId,
          number: n,
          durationSeconds: durationSeconds,
          videoUrl: (videoUrl?.isEmpty ?? true) ? null : videoUrl,
        ),
      );
    }
  }

  @override
  Future<Settings> getSettings() async => settings;

  @override
  Future<void> saveSettings(Settings s) async => settings = s;

  @override
  Future<List<CoinPackRow>> listCoinPacks() async => [...packs];

  @override
  Future<void> saveCoinPack(CoinPackRow pack) async {
    if (pack.id == null) {
      pack.id = _nextId++;
      packs.add(pack);
    }
  }

  @override
  Future<void> deleteCoinPack(int id) async =>
      packs.removeWhere((p) => p.id == id);

  @override
  Future<List<PassRow>> listPasses() async => [...passes];

  @override
  Future<void> savePass(PassRow pass) async {
    passes
      ..removeWhere((p) => p.id == pass.id)
      ..add(pass);
  }

  @override
  Future<void> deletePass(String id) async =>
      passes.removeWhere((p) => p.id == id);

  @override
  Future<List<HomeRowRow>> listHomeRows() async => [...homeRows];

  @override
  Future<void> saveHomeRow(HomeRowRow row) async {
    if (row.id == null) {
      row.id = _nextId++;
      homeRows.add(row);
    }
  }

  @override
  Future<void> deleteHomeRow(int id) async =>
      homeRows.removeWhere((r) => r.id == id);
}
