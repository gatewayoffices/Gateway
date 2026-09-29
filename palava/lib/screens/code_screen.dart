import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/backend.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../widgets/common.dart';

/// Enter the 6-digit code texted to [phone].
class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key, required this.phone});

  final String phone;

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  static const _resendAfter = 30;

  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  int _resendIn = _resendAfter;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    final state = AppStateScope.read(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.verifyPhoneCode(widget.phone, code);
      // Signed in: the app switches to Home underneath this screen.
      navigator.popUntil((route) => route.isFirst);
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await AppStateScope.read(context).sendPhoneCode(widget.phone);
      if (!mounted) return;
      _startResendTimer();
      showSampleMessage(context, 'We sent a new code.');
    } on BackendException catch (e) {
      if (mounted) showSampleMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text('Enter your code', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              state.backend.isSample
                  ? 'Sample mode: no text is sent. Enter any 6 digits.'
                  : 'We texted a 6-digit code to ${widget.phone}.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 12,
                fontWeight: FontWeight.w700,
                color: PalavaColors.text,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                errorText: _error,
              ),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Verify'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _resendIn > 0 || _busy ? null : _resend,
              child: Text(
                _resendIn > 0
                    ? 'Send a new code in $_resendIn s'
                    : 'Send a new code',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
