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
    this.posterUrl,
    this.freeEpisodes,
    this.unlockCostCoins,
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
  final String? posterUrl;

  /// Per-series overrides; null means use [AppConfig].
  final int? freeEpisodes;
  final int? unlockCostCoins;

  String get primaryGenre => genres.isEmpty ? '' : genres.first;

  /// Reads a row of the `series_catalog` view.
  factory Series.fromJson(Map<String, dynamic> json) => Series(
    id: json['id'] as String,
    title: json['title'] as String,
    tagline: json['tagline'] as String? ?? '',
    synopsis: json['synopsis'] as String? ?? '',
    genres: List<String>.from(json['genres'] as List? ?? const []),
    episodeCount: json['episode_count'] as int? ?? 0,
    language: json['language'] as String? ?? '',
    ageRating: json['age_rating'] as String? ?? '',
    posterColors: _colors(json['poster_colors'] as List?),
    posterUrl: json['poster_url'] as String?,
    freeEpisodes: json['free_episodes'] as int?,
    unlockCostCoins: json['unlock_cost_coins'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'tagline': tagline,
    'synopsis': synopsis,
    'genres': genres,
    'episode_count': episodeCount,
    'language': language,
    'age_rating': ageRating,
    'poster_colors': [for (final c in posterColors) _hex(c)],
    'poster_url': posterUrl,
    'free_episodes': freeEpisodes,
    'unlock_cost_coins': unlockCostCoins,
  };

  static List<Color> _colors(List? hexes) {
    final parsed = [
      for (final hex in hexes ?? const [])
        if (int.tryParse((hex as String).replaceFirst('#', ''), radix: 16)
            case final value?)
          Color(0xFF000000 | value),
    ];
    return parsed.length >= 2
        ? parsed.take(2).toList()
        : const [Color(0xFF5A3A1F), Color(0xFF1A0F07)];
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
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
  const CoinPack({
    required this.coins,
    this.bonusCoins = 0,
    this.id,
    this.priceLabel,
  });

  final int? id;
  final int coins;
  final int bonusCoins;

  /// Null means use [AppConfig.priceLabel].
  final String? priceLabel;

  factory CoinPack.fromJson(Map<String, dynamic> json) => CoinPack(
    id: json['id'] as int?,
    coins: json['coins'] as int,
    bonusCoins: json['bonus_coins'] as int? ?? 0,
    priceLabel: json['price_label'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'coins': coins,
    'bonus_coins': bonusCoins,
    'price_label': priceLabel,
  };
}

class Pass {
  const Pass({
    required this.name,
    required this.description,
    this.id,
    this.priceLabel,
  });

  final String? id;
  final String name;
  final String description;
  final String? priceLabel;

  factory Pass.fromJson(Map<String, dynamic> json) => Pass(
    id: json['id'] as String?,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    priceLabel: json['price_label'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'price_label': priceLabel,
  };
}

/// A row of series on the Home screen.
class HomeRow {
  const HomeRow({required this.title, required this.seriesIds});

  final String title;
  final List<String> seriesIds;

  factory HomeRow.fromJson(Map<String, dynamic> json) => HomeRow(
    title: json['title'] as String,
    seriesIds: List<String>.from(json['series_ids'] as List? ?? const []),
  );

  Map<String, dynamic> toJson() => {'title': title, 'series_ids': seriesIds};
}

/// Everything the business may change without releasing a new app. Loaded
/// from the backend (`app_settings`, `coin_packs`, `passes`, `home_rows`);
/// Milestone 5's admin panel edits it.
class AppConfig {
  const AppConfig({
    required this.freeEpisodeCount,
    required this.unlockCostCoins,
    required this.freeAdsPerDay,
    required this.dataSaverMaxBitrate,
    required this.coinPacks,
    required this.passes,
    required this.homeRows,
    required this.priceLabel,
  });

  final int freeEpisodeCount;
  final int unlockCostCoins;
  final int freeAdsPerDay;

  /// Highest video bitrate (bits per second) played while Data saver is on.
  final int dataSaverMaxBitrate;
  final List<CoinPack> coinPacks;
  final List<Pass> passes;
  final List<HomeRow> homeRows;

  /// Prices are not set yet, so every price shows this placeholder.
  final String priceLabel;

  int freeEpisodesFor(Series series) => series.freeEpisodes ?? freeEpisodeCount;

  int unlockCostFor(Series series) => series.unlockCostCoins ?? unlockCostCoins;

  bool isEpisodeFree(Series series, int episodeNumber) =>
      episodeNumber <= freeEpisodesFor(series);

  String priceOf({String? label}) => label ?? priceLabel;

  Map<String, dynamic> toJson() => {
    'free_episode_count': freeEpisodeCount,
    'unlock_cost_coins': unlockCostCoins,
    'free_ads_per_day': freeAdsPerDay,
    'data_saver_max_bitrate': dataSaverMaxBitrate,
    'price_label': priceLabel,
    'coin_packs': [for (final p in coinPacks) p.toJson()],
    'passes': [for (final p in passes) p.toJson()],
    'home_rows': [for (final r in homeRows) r.toJson()],
  };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    freeEpisodeCount: json['free_episode_count'] as int,
    unlockCostCoins: json['unlock_cost_coins'] as int,
    freeAdsPerDay: json['free_ads_per_day'] as int,
    dataSaverMaxBitrate: json['data_saver_max_bitrate'] as int,
    priceLabel: json['price_label'] as String,
    coinPacks: [
      for (final p in json['coin_packs'] as List)
        CoinPack.fromJson(p as Map<String, dynamic>),
    ],
    passes: [
      for (final p in json['passes'] as List)
        Pass.fromJson(p as Map<String, dynamic>),
    ],
    homeRows: [
      for (final r in json['home_rows'] as List)
        HomeRow.fromJson(r as Map<String, dynamic>),
    ],
  );
}

/// Everything shown in the app's browsing screens.
class Catalog {
  Catalog({
    required this.series,
    required this.config,
    this.featuredSeriesId,
    this.forYouSeriesIds = const [],
  }) : _byId = {for (final s in series) s.id: s};

  final List<Series> series;
  final AppConfig config;
  final String? featuredSeriesId;
  final List<String> forYouSeriesIds;
  final Map<String, Series> _byId;

  Series? seriesById(String id) => _byId[id];

  /// Series ids in [ids] that exist, as series (skips removed ones).
  List<Series> seriesFor(Iterable<String> ids) => [
    for (final id in ids) ?_byId[id],
  ];

  Series? get featured =>
      (featuredSeriesId == null ? null : _byId[featuredSeriesId!]) ??
      (series.isEmpty ? null : series.first);

  List<Series> get forYou {
    final picked = seriesFor(forYouSeriesIds);
    return picked.isEmpty ? series : picked;
  }

  List<String> get genres => {for (final s in series) ...s.genres}.toList();

  Map<String, dynamic> toJson() => {
    'series': [for (final s in series) s.toJson()],
    'config': config.toJson(),
    'featured_series_id': featuredSeriesId,
    'for_you_series_ids': forYouSeriesIds,
  };

  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
    series: [
      for (final s in json['series'] as List)
        Series.fromJson(s as Map<String, dynamic>),
    ],
    config: AppConfig.fromJson(json['config'] as Map<String, dynamic>),
    featuredSeriesId: json['featured_series_id'] as String?,
    forYouSeriesIds: List<String>.from(
      json['for_you_series_ids'] as List? ?? const [],
    ),
  );
}

/// One episode of a series.
class Episode {
  const Episode({
    required this.seriesId,
    required this.number,
    this.videoUrl,
    this.subtitlesVtt,
    this.endsAt,
  });

  final String seriesId;
  final int number;

  /// HLS stream (.m3u8) from the video host. Null when the viewer may not
  /// watch this episode yet (locked): the server hides the link.
  final String? videoUrl;

  /// WebVTT subtitles, if the episode has them.
  final String? subtitlesVtt;

  /// Where the episode ends. For the sample test streams this is earlier
  /// than the end of the video.
  final Duration? endsAt;

  bool get isPlayable => videoUrl != null;
}
