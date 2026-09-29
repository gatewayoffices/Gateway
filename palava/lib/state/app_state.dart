import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

/// App state for the prototype. Watch history and playback settings are saved
/// on the phone; the wallet and My List live in memory until the backend
/// (Milestone 4) stores them.
class AppState extends ChangeNotifier {
  AppState({
    AppConfig? config,
    SharedPreferences? prefs,
    VideoControllerFactory? videoFactory,
  }) : config = config ?? SampleData.config,
       _prefs = prefs,
       history = WatchHistory(prefs),
       createVideoController = videoFactory ?? createNetworkController,
       dataSaver = prefs?.getBool(_dataSaverKey) ?? true,
       subtitles = prefs?.getBool(_subtitlesKey) ?? true;

  static const _dataSaverKey = 'data_saver';
  static const _subtitlesKey = 'subtitles';

  final AppConfig config;
  final SharedPreferences? _prefs;
  final WatchHistory history;
  final VideoControllerFactory createVideoController;

  AppLanguage language = AppLanguage.english;
  final Set<String> favouriteGenres = {};

  String? phoneNumber;
  String displayName = 'Guest';
  bool get isGuest => phoneNumber == null;

  int coinBalance = 45;
  int adsWatchedToday = 0;
  bool autoUnlock = false;

  bool dataSaver;
  bool subtitles;
  bool wifiOnlyDownloads = true;
  bool notifications = true;

  final Set<String> myList = {'waterside', 'diaspora-daughter'};
  final Set<String> liked = {};
  final Map<String, Set<int>> _unlocked = {};

  int get adsLeftToday =>
      (config.freeAdsPerDay - adsWatchedToday).clamp(0, config.freeAdsPerDay);

  String get maskedPhone {
    final phone = phoneNumber;
    if (phone == null || phone.length < 4) return 'Not signed in';
    final visible = phone.substring(phone.length - 3);
    return '+231 ** *** $visible';
  }

  bool isUnlocked(String seriesId, int episodeNumber) =>
      config.isEpisodeFree(episodeNumber) ||
      (_unlocked[seriesId]?.contains(episodeNumber) ?? false);

  void setLanguage(AppLanguage value) {
    language = value;
    notifyListeners();
  }

  void toggleGenre(String genre) {
    if (!favouriteGenres.remove(genre)) favouriteGenres.add(genre);
    notifyListeners();
  }

  void signIn(String phone) {
    phoneNumber = phone;
    displayName = 'Palava viewer';
    notifyListeners();
  }

  void signOut() {
    phoneNumber = null;
    displayName = 'Guest';
    notifyListeners();
  }

  void toggleMyList(String seriesId) {
    if (!myList.remove(seriesId)) myList.add(seriesId);
    notifyListeners();
  }

  void toggleLike(String seriesId) {
    if (!liked.remove(seriesId)) liked.add(seriesId);
    notifyListeners();
  }

  /// Returns false when the balance is too low.
  bool unlockWithCoins(String seriesId, int episodeNumber) {
    if (coinBalance < config.unlockCostCoins) return false;
    coinBalance -= config.unlockCostCoins;
    _unlock(seriesId, episodeNumber);
    return true;
  }

  /// Returns false when there are no free ads left today.
  bool unlockWithAd(String seriesId, int episodeNumber) {
    if (adsLeftToday == 0) return false;
    adsWatchedToday++;
    _unlock(seriesId, episodeNumber);
    return true;
  }

  /// Sample only: pretend a purchase succeeded. Real payments go through the
  /// provider's hosted checkout in Milestone 6.
  void addSampleCoins(int coins) {
    coinBalance += coins;
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

  /// Rows for "Continue watching": real history once the viewer has watched
  /// something, sample rows before that.
  List<ContinueWatching> get continueWatching {
    if (history.isEmpty) return SampleData.continueWatching;
    return [
      for (final entry in history.recent)
        ContinueWatching(
          seriesId: entry.seriesId,
          episodeNumber: entry.episodeNumber,
          progress: entry.progress,
        ),
    ];
  }

  /// Saves where the viewer is. Playback calls this every few seconds with
  /// [refreshScreens] false, and once with true when the viewer moves on, so
  /// screens are not rebuilt constantly during playback.
  void recordProgress(WatchEntry entry, {bool refreshScreens = false}) {
    history.record(entry);
    // Deferred: this can be called while a screen is closing, when widgets
    // may not be rebuilt.
    if (refreshScreens) scheduleMicrotask(notifyListeners);
  }

  void setWifiOnlyDownloads(bool value) {
    wifiOnlyDownloads = value;
    notifyListeners();
  }

  void setNotifications(bool value) {
    notifications = value;
    notifyListeners();
  }

  void _unlock(String seriesId, int episodeNumber) {
    _unlocked.putIfAbsent(seriesId, () => {}).add(episodeNumber);
    notifyListeners();
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
