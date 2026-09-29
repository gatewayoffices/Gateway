import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/palava_colors.dart';
import '../theme/palava_theme.dart';

/// A placeholder poster painted from the series colours, so the app works
/// without downloading any images. Real artwork arrives with the backend.
class PosterArt extends StatelessWidget {
  const PosterArt({
    super.key,
    required this.series,
    this.showTitle = true,
    this.titleSize = 16,
    this.borderRadius = PalavaRadius.small,
    this.child,
  });

  final Series series;
  final bool showTitle;
  final double titleSize;
  final double borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: series.posterColors,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft "firelight" glow in the corner.
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      PalavaColors.gold.withValues(alpha: 0.35),
                      PalavaColors.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            if (showTitle)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  series.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PalavaFonts.title,
                    fontWeight: FontWeight.w700,
                    fontSize: titleSize,
                    height: 1.1,
                    color: PalavaColors.text,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black54),
                    ],
                  ),
                ),
              ),
            ?child,
          ],
        ),
      ),
    );
  }
}
