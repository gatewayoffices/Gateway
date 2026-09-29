import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../theme/palava_theme.dart';
import '../widgets/common.dart';
import 'wallet_screen.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _chooseLanguage(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in AppLanguage.values)
              ListTile(
                minTileHeight: 56,
                title: Text(language.label),
                trailing: state.language == language
                    ? const Icon(Icons.check, color: PalavaColors.ember)
                    : null,
                onTap: () {
                  state.setLanguage(language);
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _logOut(BuildContext context, AppState state) {
    state.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Profile', style: textTheme.headlineMedium),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: PalavaColors.card,
                child: Text(
                  state.displayName.characters.first,
                  style: const TextStyle(
                    fontFamily: PalavaFonts.title,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: PalavaColors.ember,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.displayName, style: textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(state.maskedPhone, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              minTileHeight: 64,
              leading: const CoinIcon(size: 28),
              title: const Text('Wallet'),
              subtitle: Text('${state.coinBalance} coins'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Group(
            children: [
              _NavTile(
                icon: Icons.download_outlined,
                title: 'Downloads',
                onTap: () => showSampleMessage(
                  context,
                  'Downloads arrive in Milestone 7.',
                ),
              ),
              _SwitchTile(
                icon: Icons.data_saver_on_outlined,
                title: 'Data saver',
                subtitle: 'Lower video quality to use less data',
                value: state.dataSaver,
                onChanged: state.setDataSaver,
              ),
              _SwitchTile(
                icon: Icons.wifi,
                title: 'Download on WiFi only',
                value: state.wifiOnlyDownloads,
                onChanged: state.setWifiOnlyDownloads,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Group(
            children: [
              _NavTile(
                icon: Icons.language,
                title: 'Language',
                trailingText: state.language.label,
                onTap: () => _chooseLanguage(context, state),
              ),
              _SwitchTile(
                icon: Icons.notifications_none,
                title: 'Notifications',
                value: state.notifications,
                onChanged: state.setNotifications,
              ),
              _NavTile(
                icon: Icons.help_outline,
                title: 'Help',
                onTap: () => showSampleMessage(
                  context,
                  'Help pages will be added later.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Group(
            children: [
              _NavTile(
                icon: Icons.logout,
                title: state.isGuest ? 'Sign in' : 'Log out',
                color: PalavaColors.ember,
                onTap: () => _logOut(context, state),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingText,
    this.color,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? trailingText;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      leading: Icon(icon, color: color ?? PalavaColors.textSecondary),
      title: Text(title, style: TextStyle(color: color)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(trailingText!, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: PalavaColors.textQuiet),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: PalavaColors.textSecondary),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
    );
  }
}
