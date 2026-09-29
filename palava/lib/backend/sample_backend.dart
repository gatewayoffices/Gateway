import 'dart:async';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../playback/watch_history.dart';
import 'backend.dart';

/// Pretend server that lives in the app's memory. Used until Supabase is set
/// up, and in tests. It follows the same rules as the real database: coins
/// are checked, locked episodes have no video link, ads are limited per day.
class SampleBackend implements Backend {
  SampleBackend({Catalog? catalog}) : _catalog = catalog ?? SampleData.catalog;

  final Catalog _catalog;
  final _users = StreamController<BackendUser?>.broadcast();
  BackendUser? _user;

  int _balance = 45;
  int _adsUsed = 0;
  final Map<String, Set<int>> _unlocked = {};
  final Set<String> _myList = {'waterside', 'diaspora-daughter'};
  final Set<String> _liked = {};
  DateTime? _passEndsAt;
  final List<PurchaseSummary> _purchases = [];
  int _nextPurchase = 1;

  bool get _hasPass =>
      _passEndsAt != null && DateTime.now().isBefore(_passEndsAt!);

  @override
  bool get isSample => true;

  @override
  bool get supportsGoogle => false;

  @override
  Catalog? get cachedCatalog => _catalog;

  @override
  Future<Catalog> loadCatalog() async => _catalog;

  bool _canWatch(Series series, int number) =>
      _hasPass ||
      _catalog.config.isEpisodeFree(series, number) ||
      (_unlocked[series.id]?.contains(number) ?? false);

  @override
  Future<Episode> loadEpisode(Series series, int number) async {
    final episode = SampleData.episodesFor(series)[number - 1];
    if (_canWatch(series, number)) return episode;
    return Episode(seriesId: series.id, number: number, endsAt: episode.endsAt);
  }

  @override
  BackendUser? get currentUser => _user;

  @override
  Stream<BackendUser?> get userChanges => _users.stream;

  @override
  Future<void> sendPhoneCode(String phone) async {}

  @override
  Future<void> verifyPhoneCode(String phone, String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const BackendException(BackendErrorKind.invalidCode);
    }
    _user = BackendUser(id: 'sample-user', phone: phone);
    _users.add(_user);
  }

  @override
  Future<void> signInWithGoogle() async =>
      throw const BackendException(BackendErrorKind.unknown, 'Not available');

  @override
  Future<void> signOut() async {
    _user = null;
    _users.add(null);
  }

  @override
  Future<ViewerData> loadViewer() async => snapshot();

  /// The current viewer data, available without waiting.
  ViewerData snapshot() => ViewerData(
    coinBalance: _balance,
    adsLeftToday: _adsLeft,
    unlocked: {
      for (final e in _unlocked.entries) e.key: {...e.value},
    },
    myList: {..._myList},
    liked: {..._liked},
    history: const [],
    displayName: _user == null ? null : 'Palava viewer',
    phone: _user?.phone,
    hasActivePass: _hasPass,
    passEndsAt: _hasPass ? _passEndsAt : null,
    recentPurchases: [..._purchases.reversed.take(5)],
  );

  int get _adsLeft =>
      (_catalog.config.freeAdsPerDay - _adsUsed).clamp(0, 1 << 30);

  @override
  Future<int> unlockWithCoins(Series series, int episodeNumber) async {
    if (_canWatch(series, episodeNumber)) return _balance;
    final cost = _catalog.config.unlockCostFor(series);
    if (_balance < cost) {
      throw const BackendException(BackendErrorKind.notEnoughCoins);
    }
    _balance -= cost;
    _unlocked.putIfAbsent(series.id, () => {}).add(episodeNumber);
    return _balance;
  }

  @override
  Future<int> unlockWithAd(Series series, int episodeNumber) async {
    if (_canWatch(series, episodeNumber)) return _adsLeft;
    if (_adsLeft == 0) {
      throw const BackendException(BackendErrorKind.noAdsLeft);
    }
    _adsUsed++;
    _unlocked.putIfAbsent(series.id, () => {}).add(episodeNumber);
    return _adsLeft;
  }

  /// Sample mode: every purchase goes through at once and nothing is charged.
  @override
  Future<PurchaseTicket> startPurchase({
    int? coinPackId,
    String? passId,
    required String paymentMethod,
  }) async {
    final config = _catalog.config;
    final String name;
    if (passId != null) {
      final pass = config.passes.firstWhere((p) => p.id == passId);
      final start = _hasPass ? _passEndsAt! : DateTime.now();
      _passEndsAt = start.add(Duration(hours: pass.durationHours));
      name = pass.name;
    } else {
      final pack = config.coinPacks.firstWhere((p) => p.id == coinPackId);
      _balance += pack.coins + pack.bonusCoins;
      name = '${pack.coins + pack.bonusCoins} coins';
    }
    final ticket = PurchaseTicket(
      id: _nextPurchase,
      reference: 'SAMPLE-${_nextPurchase++}',
    );
    _purchases.add(
      PurchaseSummary(
        reference: ticket.reference,
        productName: name,
        status: PurchaseStatus.paid,
        createdAt: DateTime.now(),
      ),
    );
    return ticket;
  }

  @override
  Future<void> setInMyList(String seriesId, bool inList) async =>
      inList ? _myList.add(seriesId) : _myList.remove(seriesId);

  @override
  Future<void> setLiked(String seriesId, bool liked) async =>
      liked ? _liked.add(seriesId) : _liked.remove(seriesId);

  @override
  Future<void> saveProgress(WatchEntry entry) async {}

  @override
  Future<void> updateProfile({String? language, List<String>? genres}) async {}
}
