import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../theme/palava_theme.dart';
import '../widgets/common.dart';
import '../widgets/poster_art.dart';
import 'player_screen.dart';
import 'series_screen.dart';
import 'wallet_screen.dart';

void openSeries(BuildContext context, Series series) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => SeriesScreen(series: series)));
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final featured = SampleData.seriesById(SampleData.featuredSeriesId);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(child: PalavaLogo()),
                    ),
                  ),
                  CoinBadge(
                    coins: state.coinBalance,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WalletScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Search',
                    iconSize: 26,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      final picked = await showSearch<Series?>(
                        context: context,
                        delegate: _SeriesSearch(),
                      );
                      if (picked != null && context.mounted) {
                        openSeries(context, picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _FeaturedHero(series: featured)),
          const SliverToBoxAdapter(child: SectionHeader('Continue watching')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: state.continueWatching.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) =>
                    _ContinueCard(item: state.continueWatching[i]),
              ),
            ),
          ),
          for (final row in state.config.homeRows) ...[
            SliverToBoxAdapter(child: SectionHeader(row.title)),
            SliverToBoxAdapter(child: _SeriesRow(row: row)),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _FeaturedHero extends StatelessWidget {
  const _FeaturedHero({required this.series});

  final Series series;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: PosterArt(
          series: series,
          showTitle: false,
          borderRadius: PalavaRadius.large,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xE61A120D)],
                stops: [0.35, 1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'FEATURED  ·  ${series.primaryGenre.toUpperCase()}',
                    style: const TextStyle(
                      color: PalavaColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(series.title, style: textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Text(
                    series.tagline,
                    style: textTheme.bodyLarge?.copyWith(
                      color: PalavaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => openPlayer(context, series),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Watch now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => openSeries(context, series),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: PalavaColors.background.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        child: const Text('Details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.item});

  final ContinueWatching item;

  @override
  Widget build(BuildContext context) {
    final series = SampleData.seriesById(item.seriesId);
    return SizedBox(
      width: 124,
      child: InkWell(
        borderRadius: BorderRadius.circular(PalavaRadius.small),
        // Resume from real history, or start the sample row's episode.
        onTap: () =>
            AppStateScope.read(context).history.lastFor(series.id) != null
            ? openPlayer(context, series)
            : openPlayer(context, series, episode: item.episodeNumber),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PosterArt(
                series: series,
                titleSize: 14,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 40,
                    color: Color(0xCCF6EEE2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ProgressLine(value: item.progress),
            const SizedBox(height: 6),
            Text(
              'Episode ${item.episodeNumber}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.row});

  final HomeRow row;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: row.seriesIds.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final series = SampleData.seriesById(row.seriesIds[i]);
          return SizedBox(
            width: 124,
            child: InkWell(
              borderRadius: BorderRadius.circular(PalavaRadius.small),
              onTap: () => openSeries(context, series),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: PosterArt(series: series, titleSize: 14)),
                  const SizedBox(height: 6),
                  Text(
                    '${series.primaryGenre}  ·  ${series.episodeCount} eps',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SeriesSearch extends SearchDelegate<Series?> {
  _SeriesSearch() : super(searchFieldLabel: 'Search series');

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: PalavaColors.textQuiet),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear',
        icon: const Icon(Icons.close),
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final q = query.trim().toLowerCase();
    final matches = SampleData.series.where(
      (s) =>
          q.isEmpty ||
          s.title.toLowerCase().contains(q) ||
          s.genres.any((g) => g.toLowerCase().contains(q)),
    );
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final series in matches)
          ListTile(
            minVerticalPadding: 10,
            leading: SizedBox(
              width: 44,
              height: 60,
              child: PosterArt(series: series, showTitle: false),
            ),
            title: Text(series.title),
            subtitle: Text(
              '${series.genres.join(', ')}  ·  ${series.episodeCount} episodes',
            ),
            onTap: () => close(context, series),
          ),
      ],
    );
  }
}
