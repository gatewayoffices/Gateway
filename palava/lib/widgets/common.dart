import 'package:flutter/material.dart';

import '../theme/palava_colors.dart';
import '../theme/palava_theme.dart';

/// Text logo: "Palava" with an ember dot.
class PalavaLogo extends StatelessWidget {
  const PalavaLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Palava'),
          TextSpan(
            text: '.',
            style: TextStyle(color: PalavaColors.ember, fontSize: size * 1.1),
          ),
        ],
      ),
      style: TextStyle(
        fontFamily: PalavaFonts.title,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: PalavaColors.text,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Thin rounded progress bar in ember on a dark track.
class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.value,
    this.height = 4,
    this.trackColor = PalavaColors.cardBorder,
  });

  final double value;
  final double height;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: trackColor,
        color: PalavaColors.ember,
      ),
    );
  }
}

/// Gold coin balance pill.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.coins, this.onTap});

  final int coins;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PalavaColors.card,
      shape: const StadiumBorder(
        side: BorderSide(color: PalavaColors.cardBorder),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 18),
                const SizedBox(width: 8),
                Text(
                  '$coins',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PalavaColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PalavaColors.gold,
        border: Border.all(color: const Color(0xFFB9852C), width: size / 10),
      ),
      alignment: Alignment.center,
      child: Text(
        'P',
        style: TextStyle(
          fontFamily: PalavaFonts.title,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.55,
          height: 1,
          color: PalavaColors.background,
        ),
      ),
    );
  }
}

/// A selectable pill used for genres and choices.
class ChoiceChipPill extends StatelessWidget {
  const ChoiceChipPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? PalavaColors.ember.withValues(alpha: 0.18)
          : PalavaColors.card,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? PalavaColors.ember : PalavaColors.cardBorder,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? PalavaColors.text
                        : PalavaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showSampleMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
