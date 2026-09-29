import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../theme/palava_theme.dart';
import '../widgets/poster_art.dart';
import 'home_screen.dart';

class MyListScreen extends StatelessWidget {
  const MyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    final saved = SampleData.series
        .where((s) => state.myList.contains(s.id))
        .toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Text('My List', style: textTheme.headlineMedium),
            ),
          ),
          if (saved.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bookmark_border,
                      size: 48,
                      color: PalavaColors.textQuiet,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Series you save will show up here.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                itemCount: saved.length,
                itemBuilder: (context, i) {
                  final series = saved[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(PalavaRadius.small),
                    onTap: () => openSeries(context, series),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: PosterArt(series: series)),
                        const SizedBox(height: 6),
                        Text(
                          '${series.primaryGenre}  ·  '
                          '${series.episodeCount} eps',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
