import '../data/models.dart';
import '../playback/watch_history.dart';

/// Why an action on the server failed, in terms the app can explain.
enum BackendErrorKind {
  notEnoughCoins,
  noAdsLeft,
  signInRequired,
  invalidCode,
  offline,
  unknown,
}

class BackendException implements Exception {
  const BackendException(this.kind, [this.detail]);

  final BackendErrorKind kind;
  final String? detail;

  /// A sentence to show the viewer.
  String get message => switch (kind) {
    BackendErrorKind.notEnoughCoins => 'You do not have enough coins.',
    BackendErrorKind.noAdsLeft => 'No free ads left today.',
    BackendErrorKind.signInRequired => 'Sign in to do that.',
    BackendErrorKind.invalidCode => 'That code is not right. Try again.',
    BackendErrorKind.offline =>
      'Could not reach Palava. Check your connection and try again.',
    BackendErrorKind.unknown => 'Something went wrong. Please try again.',
  };

  @override
  String toString() => 'BackendException($kind, $detail)';
}

/// A signed-in viewer.
class BackendUser {
  const BackendUser({required this.id, this.phone, this.email, this.name});

  final String id;
  final String? phone;
  final String? email;
  final String? name;
}

/// The signed-in viewer's own data, loaded after sign-in.
class ViewerData {
  const ViewerData({
    required this.coinBalance,
    required this.adsLeftToday,
    required this.unlocked,
    required this.myList,
    required this.liked,
    required this.history,
    this.displayName,
    this.phone,
    this.hasActivePass = false,
  });

  final int coinBalance;
  final int adsLeftToday;

  /// Unlocked episodes by series id.
  final Map<String, Set<int>> unlocked;
  final Set<String> myList;
  final Set<String> liked;
  final List<WatchEntry> history;
  final String? displayName;
  final String? phone;
  final bool hasActivePass;
}

/// Everything the app needs from a server. [SampleBackend] fakes it on the
/// phone (used before Supabase is set up, and in tests); [SupabaseBackend]
/// talks to the real one.
abstract class Backend {
  /// True for the built-in sample data (no server).
  bool get isSample;

  /// Whether "Continue with Google" is offered.
  bool get supportsGoogle;

  /// The catalog available straight away (bundled sample, or the copy saved
  /// on the phone last time), so the app can open without waiting.
  Catalog? get cachedCatalog;

  /// Fetches the latest catalog.
  Future<Catalog> loadCatalog();

  /// Fetches one episode with its video link (null link if still locked).
  Future<Episode> loadEpisode(Series series, int number);

  BackendUser? get currentUser;

  /// Fires when the viewer signs in or out (including Google sign-in, which
  /// finishes in the browser).
  Stream<BackendUser?> get userChanges;

  /// Texts a 6-digit code to [phone] (international format, e.g. +23177...).
  Future<void> sendPhoneCode(String phone);

  Future<void> verifyPhoneCode(String phone, String code);

  Future<void> signInWithGoogle();

  Future<void> signOut();

  Future<ViewerData> loadViewer();

  /// Returns the new coin balance.
  Future<int> unlockWithCoins(Series series, int episodeNumber);

  /// Returns the number of free ads left today.
  Future<int> unlockWithAd(Series series, int episodeNumber);

  Future<void> setInMyList(String seriesId, bool inList);

  Future<void> setLiked(String seriesId, bool liked);

  Future<void> saveProgress(WatchEntry entry);

  Future<void> updateProfile({String? language, List<String>? genres});
}
