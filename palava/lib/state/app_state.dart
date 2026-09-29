import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/backend.dart';
import '../backend/sample_backend.dart';
import '../data/models.dart';
import '../data/sample_data.dart';
import '../playback/video_controllers.dart';
import '../playback/watch_history.dart';

enum AppLanguage { english, french }

extension AppLanguageLabel on AppLanguage {
  String get label => switch (this) {
    AppLanguage.english => 'English',
    AppLanguage.french => 'Français',
  };

  String get code => switch (this) {
    AppLanguage.english => 'en',
    AppLanguage.french => 'fr',
  };
}

/// Whether the catalog is ready to show.
enum AppPhase { loading, failed, ready }

/// Everything the screens show and do. The [backend] is the source of truth
/// for the catalog and the viewer's coins, unlocks and lists; this class keeps
/// a copy for the screens and saves playback settings on the phone.
class AppState extends ChangeNotifier {
  AppState({
    Backend? backend,
    SharedPreferences? prefs,
    VideoControllerFactory? videoFactory,
  }) : backend = backend ?? SampleBackend(),
       _prefs = prefs,
       history = WatchHistory(prefs),
       createVideoController = videoFactory ?? createNetworkController,
       dataSaver = prefs?.getBool(_dataSaverKey) ?? true,
       subtitles = prefs?.getBool(_subtitlesKey) ?? true {
    _catalog = this.backend.cachedCatalog;
    phase = _catalog == null ? AppPhase.loading : AppPhase.ready;
    if (this.backend case final SampleBackend sample) {
      _applyViewer(sample.snapshot());
    }
  }

  static const _dataSaverKey = 'data_saver';
  static const _subtitlesKey = 'subtitles';

  final Backend backend;
  final SharedPreferences? _prefs;
  final WatchHistory history;
  final VideoControllerFactory createVideoController;
  StreamSubscription<BackendUser?>? _userChanges;

  // --- Catalog ---------------------------------------------------------------

  late AppPhase phase;
  Catalog? _catalog;

  /// Technical reason the catalog last failed to load, shown in small print
  /// on the retry screen so problems can be diagnosed.
  String? catalogError;

  /// Only use once [phase] is [AppPhase.ready].
  Catalog get catalog => _catalog!;
  AppConfig get config => catalog.config;

  /// Loads the catalog and restores a signed-in viewer. Call once at launch.
  Future<void> start() async {
    _userChanges = backend.userChanges.listen(_onUserChanged);
    final user = backend.currentUser;
    if (user != null) unawaited(_signedIn(user));
    await refreshCatalog();
  }

  Future<void> refreshCatalog() async {
    if (_catalog == null) {
      phase = AppPhase.loading;
      notifyListeners();
    }
    try {
      _catalog = await backend.loadCatalog();
      phase = AppPhase.ready;
      catalogError = null;
    } on BackendException catch (e) {
      catalogError = '${e.kind.name}: ${e.detail ?? ''}';
      debugPrint('Palava: catalog failed to load ($catalogError)');
      // Keep showing the saved copy if there is one.
      if (_catalog == null) phase = AppPhase.failed;
    }
    notifyListeners();
  }

  // --- Viewer ----------------------------------------------------------------

  BackendUser? _user;
  String? _profileName;
  String? _profilePhone;

  bool get isSignedIn => _user != null;
  bool get isGuest => !isSignedIn;

  /// True once the viewer is past the Welcome screen (signed in or browsing).
  bool enteredApp = false;

  /// Guests can unlock only with the sample data; with Supabase, coins belong
  /// to an account.
  bool get canUnlock => isSignedIn || backend.isSample;

  AppLanguage language = AppLanguage.english;
  final Set<String> favouriteGenres = {};

  int coinBalance = 0;
  int adsLeftToday = 0;
  bool hasActivePass = false;
  bool autoUnlock = false;

  bool dataSaver;
  bool subtitles;
  bool wifiOnlyDownloads = true;
  bool notifications = true;

  Set<String> myList = {};
  Set<String> liked = {};
  final Map<String, Set<int>> _unlocked = {};

  String get displayName =>
      _profileName ?? _user?.name ?? (isSignedIn ? 'Palava viewer' : 'Guest');

  String get maskedPhone {
    final digits = (_profilePhone ?? _user?.phone ?? '').replaceAll(
      RegExp(r'\D'),
      '',
    );
    if (digits.length < 7) return _user?.email ?? 'Not signed in';
    return '+${digits.substring(0, 3)} ** *** '
        '${digits.substring(digits.length - 3)}';
  }

  bool isUnlocked(Series series, int episodeNumber) =>
      hasActivePass ||
      config.isEpisodeFree(series, episodeNumber) ||
      (_unlocked[series.id]?.contains(episodeNumber) ?? false);

  void browseAsGuest() {
    enteredApp = true;
    notifyListeners();
  }

  /// Sends the viewer back to the Welcome screen to sign in.
  void leaveGuestMode() {
    enteredApp = false;
    notifyListeners();
  }

  Future<void> sendPhoneCode(String phone) => backend.sendPhoneCode(phone);

  Future<void> verifyPhoneCode(String phone, String code) async {
    await backend.verifyPhoneCode(phone, code);
    await _signedIn(backend.currentUser);
  }

  /// Opens Google in the browser; the app hears back through [start]'s
  /// listener when the viewer returns.
  Future<void> signInWithGoogle() => backend.signInWithGoogle();

  Future<void> signOut() async {
    try {
      await backend.signOut();
    } on BackendException {
      // Signed out on the phone even if the server could not be told.
    }
    _signedOut();
  }

  void _onUserChanged(BackendUser? user) {
    if (user == null) {
      if (_user != null) _signedOut();
    } else {
      _signedIn(user);
    }
  }

  Future<void> _signedIn(BackendUser? user) async {
    if (user == null || user.id == _user?.id) return;
    _user = user;
    enteredApp = true;
    notifyListeners();
    unawaited(_pushWelcomeChoices());
    await refreshViewer();
  }

  void _signedOut() {
    _user = null;
    _profileName = null;
    _profilePhone = null;
    enteredApp = false;
    if (backend case final SampleBackend sample) {
      _applyViewer(sample.snapshot());
    } else {
      _applyViewer(null);
    }
    notifyListeners();
  }

  /// Reloads coins, unlocks, lists and history from the server.
  Future<void> refreshViewer() async {
    try {
      final data = await backend.loadViewer();
      _applyViewer(data);
      await _mergeHistory(data.history);
    } on BackendException {
      // Keep what is on screen; the next refresh will catch up.
    }
    notifyListeners();
  }

  void _applyViewer(ViewerData? data) {
    coinBalance = data?.coinBalance ?? 0;
    adsLeftToday = data?.adsLeftToday ?? 0;
    hasActivePass = data?.hasActivePass ?? false;
    myList = {...?data?.myList};
    liked = {...?data?.liked};
    _unlocked
      ..clear()
      ..addAll({
        for (final e in (data?.unlocked ?? const <String, Set<int>>{}).entries)
          e.key: {...e.value},
      });
    _profileName = data?.displayName;
    _profilePhone = data?.phone;
  }

  /// Newer entries win in both directions, so watching as a guest and then
  /// signing in keeps your place.
  Future<void> _mergeHistory(List<WatchEntry> server) async {
    final serverBySeries = {for (final e in server) e.seriesId: e};
    for (final entry in server) {
      final local = history.lastFor(entry.seriesId);
      if (local == null || entry.updatedAt.isAfter(local.updatedAt)) {
        history.record(entry);
      }
    }
    for (final local in history.recent) {
      final remote = serverBySeries[local.seriesId];
      if (remote == null || local.updatedAt.isAfter(remote.updatedAt)) {
        await _quietly(() => backend.saveProgress(local));
      }
    }
  }

  Future<void> _pushWelcomeChoices() => _quietly(
    () => backend.updateProfile(
      language: language.code,
      genres: favouriteGenres.isEmpty ? null : favouriteGenres.toList(),
    ),
  );

  // --- Actions ---------------------------------------------------------------

  void setLanguage(AppLanguage value) {
    language = value;
    notifyListeners();
    if (isSignedIn) {
      _quietly(() => backend.updateProfile(language: value.code));
    }
  }

  void toggleGenre(String genre) {
    if (!favouriteGenres.remove(genre)) favouriteGenres.add(genre);
    notifyListeners();
  }

  /// Throws [BackendException] (e.g. not enough coins).
  Future<void> unlockWithCoins(Series series, int episodeNumber) async {
    coinBalance = await backend.unlockWithCoins(series, episodeNumber);
    _unlocked.putIfAbsent(series.id, () => {}).add(episodeNumber);
    notifyListeners();
  }

  /// Throws [BackendException] (e.g. no ads left today).
  Future<void> unlockWithAd(Series series, int episodeNumber) async {
    adsLeftToday = await backend.unlockWithAd(series, episodeNumber);
    _unlocked.putIfAbsent(series.id, () => {}).add(episodeNumber);
    notifyListeners();
  }

  /// Sample data only: pretend a purchase went through.
  void addSampleCoins(int coins) {
    if (backend case final SampleBackend sample) {
      coinBalance = sample.addSampleCoins(coins);
      notifyListeners();
    }
  }

  void toggleMyList(String seriesId) {
    final add = !myList.contains(seriesId);
    _toggle(myList, seriesId, add);
    if (isSignedIn || backend.isSample) {
      _quietly(
        () => backend.setInMyList(seriesId, add),
        onError: () => _toggle(myList, seriesId, !add),
      );
    }
  }

  void toggleLike(String seriesId) {
    final add = !liked.contains(seriesId);
    _toggle(liked, seriesId, add);
    if (isSignedIn || backend.isSample) {
      _quietly(
        () => backend.setLiked(seriesId, add),
        onError: () => _toggle(liked, seriesId, !add),
      );
    }
  }

  void _toggle(Set<String> set, String id, bool add) {
    add ? set.add(id) : set.remove(id);
    notifyListeners();
  }

  void setAutoUnlock(bool value) {
    autoUnlock = value;
    notifyListeners();
  }

  void setDataSaver(bool value) {
    dataSaver = value;
    _prefs?.setBool(_dataSaverKey, value);
    notifyListeners();
  }

  void setSubtitles(bool value) {
    subtitles = value;
    _prefs?.setBool(_subtitlesKey, value);
    notifyListeners();
  }

  void setWifiOnlyDownloads(bool value) {
    wifiOnlyDownloads = value;
    notifyListeners();
  }

  void setNotifications(bool value) {
    notifications = value;
    notifyListeners();
  }

  // --- Watch history ---------------------------------------------------------

  /// Rows for "Continue watching": the viewer's history, or sample rows in
  /// sample mode before anything has been watched.
  List<ContinueWatching> get continueWatching {
    if (history.isEmpty) {
      return backend.isSample ? SampleData.continueWatching : const [];
    }
    return [
      for (final entry in history.recent)
        if (catalog.seriesById(entry.seriesId) != null)
          ContinueWatching(
            seriesId: entry.seriesId,
            episodeNumber: entry.episodeNumber,
            progress: entry.progress,
          ),
    ];
  }

  /// Saves where the viewer is. Playback calls this every few seconds with
  /// [refreshScreens] false, and once with true when the viewer moves on.
  /// Only that last one goes to the server, to save data.
  void recordProgress(WatchEntry entry, {bool refreshScreens = false}) {
    history.record(entry);
    if (!refreshScreens) return;
    if (isSignedIn) _quietly(() => backend.saveProgress(entry));
    // Deferred: this can be called while a screen is closing, when widgets
    // may not be rebuilt.
    scheduleMicrotask(notifyListeners);
  }

  /// Runs a background server call; failures are not shown to the viewer.
  Future<void> _quietly(
    Future<void> Function() action, {
    VoidCallback? onError,
  }) async {
    try {
      await action();
    } on BackendException {
      onError?.call();
    }
  }

  @override
  void dispose() {
    _userChanges?.cancel();
    super.dispose();
  }
}

/// Makes [AppState] available to every screen and rebuilds them on change.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing above this widget');
    return scope!.notifier!;
  }

  /// Like [of], but does not rebuild the caller on changes. Safe in initState.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing above this widget');
    return scope!.notifier!;
  }
}
