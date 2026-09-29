import '../data/models.dart';
import '../playback/watch_history.dart';

/// Why an action on the server failed, in terms the app can explain.
enum BackendErrorKind {
  notEnoughCoins,
  noAdsLeft,
  signInRequired,
  invalidCode,
  paymentsOff,
  tooManyPending,
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
    BackendErrorKind.paymentsOff => 'Payments are not open yet.',
    BackendErrorKind.tooManyPending =>
      'You have several unfinished payments. Wait for them to be confirmed, '
          'then try again.',
    BackendErrorKind.offline =>
      'Could not reach Palava. Check your connection and try again.',
    BackendErrorKind.unknown =>
      'Something went wrong. Please try again.'
          '${detail == null ? '' : ' ($detail)'}',
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

/// A payment the viewer started.
class PurchaseTicket {
  const PurchaseTicket({required this.id, required this.reference});

  final int id;

  /// Short code the viewer and the business can quote, e.g. PAL-7F3A9C21.
  final String reference;
}

enum PurchaseStatus { pending, paid, failed, refunded }

/// One of the viewer's recent payments, for the Wallet.
class PurchaseSummary {
  const PurchaseSummary({
    required this.reference,
    required this.productName,
    required this.status,
    required this.createdAt,
  });

  final String reference;
  final String productName;
  final PurchaseStatus status;
  final DateTime createdAt;
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
    this.passEndsAt,
    this.recentPurchases = const [],
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

  /// When the viewer's pass (or last of several) runs out.
  final DateTime? passEndsAt;
  final List<PurchaseSummary> recentPurchases;
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

  /// Starts paying for one coin pack or one pass. [paymentMethod] is one of
  /// mtn_momo, orange_money, card, app_store.
  Future<PurchaseTicket> startPurchase({
    int? coinPackId,
    String? passId,
    required String paymentMethod,
  });

  Future<void> setInMyList(String seriesId, bool inList);

  Future<void> setLiked(String seriesId, bool liked);

  Future<void> saveProgress(WatchEntry entry);

  Future<void> updateProfile({String? language, List<String>? genres});
}
