import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api/admin_api.dart';
import 'app.dart';

/// Uses the same env.json as the app:
///   flutter run -d chrome --dart-define-from-file=../env.json
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_url.isEmpty || _key.isEmpty) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Supabase is not set up. Start the admin panel with:\n'
              'flutter run -d chrome --dart-define-from-file=../env.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
    return;
  }
  await Supabase.initialize(url: _url, publishableKey: _key);
  runApp(AdminApp(api: SupabaseAdminApi(Supabase.instance.client)));
}
