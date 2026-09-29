import 'package:flutter/widgets.dart';

import '../data/models.dart';
import '../data/sample_data.dart';

enum AppLanguage { english, french }

extension AppLanguageLabel on AppLanguage {
  String get label => switch (this) {
    AppLanguage.english => 'English',
    AppLanguage.french => 'Français',
  };
}

/// In-memory state for the prototype. Nothing here is saved yet; the backend
/// (Milestone 4) will store the wallet, My List and watch history.
class AppState extends ChangeNotifier {
  AppState({AppConfig? config}) : config = config ?? SampleData.config;

  final AppConfig config;

  AppLanguage language = AppLanguage.english;
  final Set<String> favouriteGenres = {};

  String? phoneNumber;
  String displayName = 'Guest';
  bool get isGuest => phoneNumber == null;

  int coinBalance = 45;
  int adsWatchedToday = 0;
  bool autoUnlock = false;

  bool dataSaver = true;
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
}
