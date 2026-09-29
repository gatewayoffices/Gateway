import 'package:flutter/material.dart';

import 'api/admin_api.dart';
import 'screens/purchases_screen.dart';
import 'screens/home_rows_screen.dart';
import 'screens/series_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/store_screen.dart';
import 'widgets/common.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.api});

  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Palava admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: _Gate(api: api),
    );
  }
}

enum _Phase { checking, signedOut, notAdmin, ready }

/// Shows sign-in until an admin is signed in.
class _Gate extends StatefulWidget {
  const _Gate({required this.api});

  final AdminApi api;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  _Phase _phase = _Phase.checking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (widget.api.signedInEmail == null) {
      setState(() => _phase = _Phase.signedOut);
      return;
    }
    setState(() => _phase = _Phase.checking);
    try {
      final admin = await widget.api.isAdmin();
      setState(() => _phase = admin ? _Phase.ready : _Phase.notAdmin);
    } on AdminException catch (e) {
      setState(() {
        _error = e.message;
        _phase = _Phase.signedOut;
      });
    }
  }

  Future<void> _signIn(String email, String password) async {
    setState(() => _error = null);
    try {
      await widget.api.signIn(email, password);
      await _check();
    } on AdminException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.api.signOut();
    } on AdminException {
      // Signed out locally anyway.
    }
    setState(() => _phase = _Phase.signedOut);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.checking => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      _Phase.signedOut => SignInScreen(onSignIn: _signIn, error: _error),
      _Phase.notAdmin => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This account is not an admin',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.api.signedInEmail} can sign in, but is not on the '
                  'admin list. Add it in Supabase (see the README, "Admin '
                  'panel"), then sign in again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
      _Phase.ready => AdminShell(api: widget.api, onSignOut: _signOut),
    };
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.onSignIn, this.error});

  final Future<void> Function(String email, String password) onSignIn;
  final String? error;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    await widget.onSignIn(_email.text.trim(), _password.text);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 380,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Palava admin', style: text.headlineSmall),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (widget.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.error!,
                        style: TextStyle(color: Colors.red.shade300),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.api, required this.onSignOut});

  final AdminApi api;
  final VoidCallback onSignOut;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      SeriesListScreen(api: widget.api),
      SettingsScreen(api: widget.api),
      StoreScreen(api: widget.api),
      HomeRowsScreen(api: widget.api),
      PurchasesScreen(api: widget.api),
    ];
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Palava',
                style: TextStyle(
                  color: ember,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.movie_outlined),
                selectedIcon: Icon(Icons.movie),
                label: Text('Series'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: Text('Settings'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: Text('Store'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.view_carousel_outlined),
                selectedIcon: Icon(Icons.view_carousel),
                label: Text('Home rows'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Purchases'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}
