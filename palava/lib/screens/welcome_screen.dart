import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
  }

  void _sendCode() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) {
      showSampleMessage(context, 'Enter your phone number first.');
      return;
    }
    // Sample only: real SMS codes arrive with Supabase in Milestone 4.
    AppStateScope.of(context).signIn(digits);
    showSampleMessage(context, 'Sample mode: signed in without a code.');
    _goHome();
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
                for (final genre in SampleData.genres)
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
              onPressed: _sendCode,
              child: const Text('Send me a code'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _goHome,
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
