import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/backend.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../widgets/common.dart';
import 'code_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _phoneController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    // Liberian numbers are often written with a leading 0 (0770...).
    final digits = _phoneController.text
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    if (digits.length < 7) {
      showSampleMessage(context, 'Enter your phone number first.');
      return;
    }
    final phone = '+231$digits';
    final state = AppStateScope.read(context);
    setState(() => _busy = true);
    try {
      await state.sendPhoneCode(phone);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => CodeScreen(phone: phone)));
    } on BackendException catch (e) {
      if (mounted) showSampleMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    try {
      await AppStateScope.read(context).signInWithGoogle();
    } on BackendException catch (e) {
      if (mounted) showSampleMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const PalavaLogo(size: 40),
            const SizedBox(height: 16),
            Text(
              'African stories, one minute at a time.',
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Original micro-dramas from Liberia and across the continent. '
              'Every episode ends on a cliffhanger.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            Text('Language', style: textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final language in AppLanguage.values)
                  ChoiceChipPill(
                    label: language.label,
                    selected: state.language == language,
                    onTap: () => state.setLanguage(language),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('What do you like to watch?', style: textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in state.catalog.genres)
                  ChoiceChipPill(
                    label: genre,
                    selected: state.favouriteGenres.contains(genre),
                    onTap: () => state.toggleGenre(genre),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Text('Phone number', style: textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                LengthLimitingTextInputFormatter(12),
              ],
              style: const TextStyle(fontSize: 17, color: PalavaColors.text),
              decoration: const InputDecoration(
                hintText: '77 123 4567',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  child: Text(
                    '+231',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: PalavaColors.textSecondary,
                    ),
                  ),
                ),
                prefixIconConstraints: BoxConstraints(minWidth: 0),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _sendCode,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Send me a code'),
            ),
            if (state.backend.supportsGoogle) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _google,
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Continue with Google'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: state.browseAsGuest,
              child: const Text('Browse as a guest'),
            ),
            const SizedBox(height: 16),
            Text(
              'By continuing you agree to the Terms and Privacy Policy.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
