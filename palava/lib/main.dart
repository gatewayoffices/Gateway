import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme/palava_colors.dart';
import 'theme/palava_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: PalavaColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(PalavaApp(state: AppState()));
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
        home: const WelcomeScreen(),
      ),
    );
  }
}
