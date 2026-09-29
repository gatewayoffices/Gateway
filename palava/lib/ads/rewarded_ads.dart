import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Result of offering the viewer a rewarded ad.
enum AdOutcome {
  /// Watched to the end: the viewer earns the reward.
  rewarded,

  /// Closed before the end: no reward.
  skipped,

  /// No ad could be loaded (no connection, or no ad available).
  unavailable,
}

/// Shows a rewarded ad. [AdMobRewardedAds] on phones; [InstantRewardedAds]
/// in tests and wherever AdMob does not run.
abstract class RewardedAds {
  Future<AdOutcome> show();
}

/// Always rewards straight away. For tests and the web.
class InstantRewardedAds implements RewardedAds {
  const InstantRewardedAds();

  @override
  Future<AdOutcome> show() async => AdOutcome.rewarded;
}

/// Google AdMob rewarded ads.
///
/// The ad unit comes from env.json (`ADMOB_REWARDED_ID`). Without one, Google's
/// public test ad unit is used: it shows a sample ad and never pays out, so
/// it is safe to tap while building the app. The ad is only downloaded when
/// the viewer asks for it, to save data.
class AdMobRewardedAds implements RewardedAds {
  AdMobRewardedAds({String? adUnitId})
    : adUnitId = adUnitId ?? _configuredUnit ?? _testUnit;

  static const _configured = String.fromEnvironment('ADMOB_REWARDED_ID');
  static String? get _configuredUnit =>
      _configured.isEmpty ? null : _configured;

  /// Google's published test ad units.
  static String get _testUnit => defaultTargetPlatform == TargetPlatform.iOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';

  final String adUnitId;
  Future<void>? _started;

  @override
  Future<AdOutcome> show() async {
    _started ??= MobileAds.instance.initialize();
    await _started;

    final ad = await _load();
    if (ad == null) return AdOutcome.unavailable;

    final done = Completer<AdOutcome>();
    var rewarded = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) {
          done.complete(rewarded ? AdOutcome.rewarded : AdOutcome.skipped);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Palava: ad failed to show: ${error.message}');
        ad.dispose();
        if (!done.isCompleted) done.complete(AdOutcome.unavailable);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => rewarded = true);
    return done.future;
  }

  Future<RewardedAd?> _load() {
    final loaded = Completer<RewardedAd?>();
    // Give up on slow connections rather than leave the viewer waiting.
    final timer = Timer(const Duration(seconds: 20), () {
      if (!loaded.isCompleted) loaded.complete(null);
    });
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          timer.cancel();
          // Arrived after giving up: release it.
          loaded.isCompleted ? ad.dispose() : loaded.complete(ad);
        },
        onAdFailedToLoad: (error) {
          timer.cancel();
          debugPrint('Palava: ad failed to load: ${error.message}');
          if (!loaded.isCompleted) loaded.complete(null);
        },
      ),
    );
    return loaded.future;
  }
}
