import 'package:flutter/material.dart';

class Series {
  const Series({
    required this.id,
    required this.title,
    required this.tagline,
    required this.synopsis,
    required this.genres,
    required this.episodeCount,
    required this.language,
    required this.ageRating,
    required this.posterColors,
  });

  final String id;
  final String title;
  final String tagline;
  final String synopsis;
  final List<String> genres;
  final int episodeCount;
  final String language;
  final String ageRating;

  /// Two colours used to paint a placeholder poster until real artwork exists.
  final List<Color> posterColors;

  String get primaryGenre => genres.first;
}

/// A series the viewer has started, with how far into the episode they got.
class ContinueWatching {
  const ContinueWatching({
    required this.seriesId,
    required this.episodeNumber,
    required this.progress,
  });

  final String seriesId;
  final int episodeNumber;

  /// 0.0 to 1.0.
  final double progress;
}

class CoinPack {
  const CoinPack({required this.coins, this.bonusCoins = 0});

  final int coins;
  final int bonusCoins;
}

class Pass {
  const Pass({required this.name, required this.description});

  final String name;
  final String description;
}

/// A row of series on the Home screen.
class HomeRow {
  const HomeRow({required this.title, required this.seriesIds});

  final String title;
  final List<String> seriesIds;
}

/// Everything the business may change without releasing a new app.
///
/// For now this is filled from sample data. In Milestone 4 it will be loaded
/// from Supabase, and in Milestone 5 it will be editable in the admin panel.
class AppConfig {
  const AppConfig({
    required this.freeEpisodeCount,
    required this.unlockCostCoins,
    required this.freeAdsPerDay,
    required this.coinPacks,
    required this.passes,
    required this.homeRows,
    required this.priceLabel,
  });

  final int freeEpisodeCount;
  final int unlockCostCoins;
  final int freeAdsPerDay;
  final List<CoinPack> coinPacks;
  final List<Pass> passes;
  final List<HomeRow> homeRows;

  /// Prices are not set yet, so every price shows this placeholder.
  final String priceLabel;

  bool isEpisodeFree(int episodeNumber) => episodeNumber <= freeEpisodeCount;
}
