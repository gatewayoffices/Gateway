import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/rewarded_ads.dart';
import 'backend/backend.dart';
import 'backend/backend_config.dart';
import 'backend/sample_backend.dart';
import 'backend/supabase_backend.dart';
import 'notifications/push_service.dart';
import 'playback/episode_feed.dart';
import 'screens/home_screen.dart';
import 'screens/main_shell.dart';
import 'screens/player_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme/palava_colors.dart';
import 'theme/palava_theme.dart';
import 'widgets/common.dart';
import 'branding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: PalavaColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Supabase when env.json provides its details, otherwise the sample data.
  const config = BackendConfig.fromEnvironment;
  final Backend backend = config.isConfigured
      ? await SupabaseBackend.connect(config, prefs)
      : SampleBackend();

  final onPhone =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  // Downloads live in the app's private storage, removed with the app.
  final downloadsDir = onPhone
      ? Directory('${(await getApplicationSupportDirectory()).path}/downloads')
      : null;
  final state = AppState(
    backend: backend,
    prefs: prefs,
    rewardedAds: onPhone ? AdMobRewardedAds() : null,
    downloadsDir: downloadsDir,
    push: onPhone ? FirebasePush() : null,
  );
  runApp(PalavaApp(state: state));
  await state.start();
}

class PalavaApp extends StatelessWidget {
  const PalavaApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: buildPalavaTheme(),
        navigatorObservers: [playbackRouteObserver],
        home: const _Root(),
      ),
    );
  }
}

/// Picks the first screen: loading, Welcome, or the app itself.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late final _lifecycle = AppLifecycleListener(
    onResume: () => AppStateScope.read(context).refreshIfStale(),
  );

  final _pushListeners = <StreamSubscription<PushMessage>>[];

  @override
  void initState() {
    super.initState();
    _lifecycle; // Start listening.
    final push = AppStateScope.read(context).push;
    _pushListeners
      ..add(push.opened.listen(_open))
      ..add(push.foreground.listen(_showInApp));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    for (final listener in _pushListeners) {
      listener.cancel();
    }
    super.dispose();
  }

  /// A tapped notification opens the series (or episode) it is about.
  void _open(PushMessage message) {
    final state = AppStateScope.read(context);
    if (state.phase != AppPhase.ready || message.seriesId == null) return;
    final series = state.catalog.seriesById(message.seriesId!);
    if (series == null) return;
    if (message.episode != null) {
      openPlayer(context, series, episode: message.episode);
    } else {
      openSeries(context, series);
    }
  }

  /// While the app is open the phone shows nothing, so show it here.
  void _showInApp(PushMessage message) {
    final text = [?message.title, ?message.body].join('\n');
    if (text.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 6),
          action: message.seriesId == null
              ? null
              : SnackBarAction(label: 'Watch', onPressed: () => _open(message)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return switch (state.phase) {
      AppPhase.loading => const _Loading(),
      AppPhase.failed => _LoadFailed(
        onRetry: state.refreshCatalog,
        detail: state.catalogError,
      ),
      AppPhase.ready =>
        state.enteredApp ? const MainShell() : const WelcomeScreen(),
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PalavaLogo(size: 40),
            SizedBox(height: 24),
            CircularProgressIndicator(color: PalavaColors.ember),
          ],
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry, this.detail});

  final VoidCallback onRetry;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PalavaLogo(size: 40),
                const SizedBox(height: 24),
                Text(
                  const BackendException(BackendErrorKind.offline).message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    detail!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
