import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/rewarded_ads.dart';
import 'backend/backend.dart';
import 'backend/backend_config.dart';
import 'backend/sample_backend.dart';
import 'backend/supabase_backend.dart';
import 'playback/episode_feed.dart';
import 'screens/main_shell.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme/palava_colors.dart';
import 'theme/palava_theme.dart';
import 'widgets/common.dart';

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
  final state = AppState(
    backend: backend,
    prefs: prefs,
    rewardedAds: onPhone ? AdMobRewardedAds() : null,
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
        title: 'Palava',
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

  @override
  void initState() {
    super.initState();
    _lifecycle; // Start listening.
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
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
