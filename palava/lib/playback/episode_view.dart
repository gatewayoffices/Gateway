import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/palava_colors.dart';

/// Full-screen video for one episode: fills the screen, shows subtitles, and
/// pauses or plays when tapped.
class EpisodeVideo extends StatelessWidget {
  const EpisodeVideo({
    super.key,
    required this.controller,
    required this.showSubtitles,
    required this.onRetry,
    this.loadFailed = false,
    this.placeholder,
    this.subtitleBottomPadding = 180,
  });

  final VideoPlayerController? controller;
  final bool showSubtitles;
  final VoidCallback onRetry;

  /// The episode's details could not be fetched; offer to try again.
  final bool loadFailed;

  /// Shown behind the video while it loads (usually the poster).
  final Widget? placeholder;
  final double subtitleBottomPadding;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        ?placeholder,
        if (loadFailed && controller == null) _ErrorMessage(onRetry: onRetry),
        if (controller != null)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.hasError) return _ErrorMessage(onRetry: onRetry);
              if (!value.isInitialized) {
                return const Center(
                  child: CircularProgressIndicator(color: PalavaColors.ember),
                );
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    value.isPlaying ? controller.pause() : controller.play(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.black,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: value.size.width,
                          height: value.size.height,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                    if (value.isBuffering && value.isPlaying)
                      const Center(
                        child: CircularProgressIndicator(
                          color: PalavaColors.ember,
                        ),
                      ),
                    if (!value.isPlaying && !value.isBuffering)
                      const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 84,
                          color: Color(0xCCF6EEE2),
                        ),
                      ),
                    if (showSubtitles && value.caption.text.isNotEmpty)
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: subtitleBottomPadding,
                        child: _Subtitle(value.caption.text),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PalavaColors.background.withValues(alpha: 0.7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 44,
                color: PalavaColors.textQuiet,
              ),
              const SizedBox(height: 12),
              Text(
                'This episode could not load. Check your connection.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin progress bar you can drag to jump within the episode.
class EpisodeProgressBar extends StatefulWidget {
  const EpisodeProgressBar({super.key, required this.controller, this.endsAt});

  final VideoPlayerController controller;

  /// Where the episode counts as finished, if earlier than the video's end.
  final Duration? endsAt;

  @override
  State<EpisodeProgressBar> createState() => _EpisodeProgressBarState();
}

class _EpisodeProgressBarState extends State<EpisodeProgressBar> {
  double? _dragValue;

  Duration _length(VideoPlayerValue value) {
    final endsAt = widget.endsAt;
    if (endsAt == null || value.duration == Duration.zero) {
      return value.duration;
    }
    return endsAt < value.duration ? endsAt : value.duration;
  }

  void _seekTo(double fraction, VideoPlayerValue value) {
    final length = _length(value);
    widget.controller.seekTo(length * fraction.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final length = _length(value);
        final progress =
            _dragValue ??
            (length == Duration.zero
                ? 0.0
                : (value.position.inMilliseconds / length.inMilliseconds).clamp(
                    0.0,
                    1.0,
                  ));
        return LayoutBuilder(
          builder: (context, constraints) {
            double fractionAt(double dx) =>
                (dx / constraints.maxWidth).clamp(0.0, 1.0);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _seekTo(fractionAt(d.localPosition.dx), value),
              onHorizontalDragUpdate: (d) =>
                  setState(() => _dragValue = fractionAt(d.localPosition.dx)),
              onHorizontalDragEnd: (_) {
                final target = _dragValue;
                setState(() => _dragValue = null);
                if (target != null) _seekTo(target, value);
              },
              // Tall hit area, thin visible bar.
              child: SizedBox(
                height: 24,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: _dragValue == null ? 3 : 6,
                      backgroundColor: PalavaColors.text.withValues(alpha: 0.2),
                      color: PalavaColors.ember,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
