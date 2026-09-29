/// Plain copies of database rows the admin panel edits. Column names match
/// supabase/migrations.
library;

List<String> _strings(Object? value) =>
    List<String>.from(value as List? ?? const []);

class SeriesRow {
  SeriesRow({
    required this.id,
    required this.title,
    this.tagline = '',
    this.synopsis = '',
    this.genres = const [],
    this.language = 'English',
    this.ageRating = '13+',
    this.posterColors = const ['#5A3A1F', '#1A0F07'],
    this.freeEpisodeCount,
    this.unlockCostCoins,
    this.published = false,
    this.episodeCount = 0,
  });

  String id;
  String title;
  String tagline;
  String synopsis;
  List<String> genres;
  String language;
  String ageRating;
  List<String> posterColors;

  /// Null means use the app-wide setting.
  int? freeEpisodeCount;
  int? unlockCostCoins;
  bool published;

  /// Read only: number of episodes (all, including hidden ones).
  int episodeCount;

  factory SeriesRow.fromJson(Map<String, dynamic> json) {
    final counts = json['episodes'];
    return SeriesRow(
      id: json['id'] as String,
      title: json['title'] as String,
      tagline: json['tagline'] as String? ?? '',
      synopsis: json['synopsis'] as String? ?? '',
      genres: _strings(json['genres']),
      language: json['language'] as String? ?? '',
      ageRating: json['age_rating'] as String? ?? '',
      posterColors: _strings(json['poster_colors']),
      freeEpisodeCount: json['free_episode_count'] as int?,
      unlockCostCoins: json['unlock_cost_coins'] as int?,
      published: json['published'] as bool? ?? false,
      episodeCount: counts is List && counts.isNotEmpty
          ? (counts.first as Map<String, dynamic>)['count'] as int? ?? 0
          : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'tagline': tagline,
    'synopsis': synopsis,
    'genres': genres,
    'language': language,
    'age_rating': ageRating,
    'poster_colors': posterColors,
    'free_episode_count': freeEpisodeCount,
    'unlock_cost_coins': unlockCostCoins,
    'published': published,
  };

  /// Makes a web-address-safe id from a title: "The Bride Price" ->
  /// "the-bride-price".
  static String slugFor(String title) => title
      .toLowerCase()
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

class EpisodeRow {
  EpisodeRow({
    this.id,
    required this.seriesId,
    required this.number,
    this.title,
    this.durationSeconds,
    this.published = true,
    this.videoUrl,
    this.subtitlesVtt,
  });

  /// Null until saved.
  int? id;
  String seriesId;
  int number;
  String? title;
  int? durationSeconds;
  bool published;

  /// Stored separately (episode_media) so locked links stay private.
  String? videoUrl;
  String? subtitlesVtt;

  factory EpisodeRow.fromJson(Map<String, dynamic> json) {
    final media = switch (json['episode_media']) {
      final Map<String, dynamic> m => m,
      [final Map<String, dynamic> m, ...] => m,
      _ => null,
    };
    return EpisodeRow(
      id: json['id'] as int,
      seriesId: json['series_id'] as String,
      number: json['number'] as int,
      title: json['title'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      published: json['published'] as bool? ?? true,
      videoUrl: media?['video_url'] as String?,
      subtitlesVtt: media?['subtitles_vtt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'series_id': seriesId,
    'number': number,
    'title': title,
    'duration_seconds': durationSeconds,
    'published': published,
  };
}

class Settings {
  Settings({
    required this.freeEpisodeCount,
    required this.unlockCostCoins,
    required this.freeAdsPerDay,
    required this.welcomeCoins,
    required this.dataSaverMaxBitrate,
    required this.priceLabel,
    this.featuredSeriesId,
    this.forYouSeriesIds = const [],
    this.paymentMode = 'test',
  });

  int freeEpisodeCount;
  int unlockCostCoins;
  int freeAdsPerDay;
  int welcomeCoins;
  int dataSaverMaxBitrate;
  String priceLabel;
  String? featuredSeriesId;
  List<String> forYouSeriesIds;

  /// 'test' (admins confirm each purchase) or 'off' (Pay is closed).
  String paymentMode;

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    freeEpisodeCount: json['free_episode_count'] as int,
    unlockCostCoins: json['unlock_cost_coins'] as int,
    freeAdsPerDay: json['free_ads_per_day'] as int,
    welcomeCoins: json['welcome_coins'] as int,
    dataSaverMaxBitrate: json['data_saver_max_bitrate'] as int,
    priceLabel: json['price_label'] as String,
    featuredSeriesId: json['featured_series_id'] as String?,
    forYouSeriesIds: _strings(json['for_you_series_ids']),
    paymentMode: json['payment_mode'] as String? ?? 'test',
  );

  Map<String, dynamic> toJson() => {
    'free_episode_count': freeEpisodeCount,
    'unlock_cost_coins': unlockCostCoins,
    'free_ads_per_day': freeAdsPerDay,
    'welcome_coins': welcomeCoins,
    'data_saver_max_bitrate': dataSaverMaxBitrate,
    'price_label': priceLabel,
    'featured_series_id': featuredSeriesId,
    'for_you_series_ids': forYouSeriesIds,
    'payment_mode': paymentMode,
  };
}

/// A viewer's purchase, as listed on the Purchases page.
class PurchaseRow {
  PurchaseRow({
    required this.id,
    required this.reference,
    required this.createdAt,
    required this.status,
    required this.provider,
    required this.productName,
    required this.viewer,
    this.paymentMethod,
    this.priceLabel,
  });

  final int id;
  final String reference;
  final DateTime createdAt;

  /// pending, paid, failed or refunded.
  final String status;

  /// Who takes the money: 'test' while payments are in test mode.
  final String provider;
  final String productName;

  /// The viewer's phone number or email.
  final String viewer;
  final String? paymentMethod;
  final String? priceLabel;

  bool get isPending => status == 'pending';
  bool get canConfirm =>
      isPending && (provider == 'test' || provider == 'manual');

  factory PurchaseRow.fromJson(Map<String, dynamic> json) => PurchaseRow(
    id: json['id'] as int,
    reference: json['reference'] as String? ?? '#${json['id']}',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    status: json['status'] as String,
    provider: json['provider'] as String,
    productName: json['product_name'] as String? ?? '',
    viewer: json['viewer'] as String? ?? '',
    paymentMethod: json['payment_method'] as String?,
    priceLabel: json['price_label'] as String?,
  );
}

class CoinPackRow {
  CoinPackRow({
    this.id,
    required this.coins,
    this.bonusCoins = 0,
    this.priceLabel,
    this.position = 0,
    this.active = true,
  });

  int? id;
  int coins;
  int bonusCoins;
  String? priceLabel;
  int position;
  bool active;

  factory CoinPackRow.fromJson(Map<String, dynamic> json) => CoinPackRow(
    id: json['id'] as int,
    coins: json['coins'] as int,
    bonusCoins: json['bonus_coins'] as int? ?? 0,
    priceLabel: json['price_label'] as String?,
    position: json['position'] as int? ?? 0,
    active: json['active'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'coins': coins,
    'bonus_coins': bonusCoins,
    'price_label': priceLabel,
    'position': position,
    'active': active,
  };
}

class PassRow {
  PassRow({
    required this.id,
    required this.name,
    this.description = '',
    required this.durationHours,
    this.priceLabel,
    this.position = 0,
    this.active = true,
  });

  String id;
  String name;
  String description;
  int durationHours;
  String? priceLabel;
  int position;
  bool active;

  factory PassRow.fromJson(Map<String, dynamic> json) => PassRow(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    durationHours: json['duration_hours'] as int,
    priceLabel: json['price_label'] as String?,
    position: json['position'] as int? ?? 0,
    active: json['active'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'duration_hours': durationHours,
    'price_label': priceLabel,
    'position': position,
    'active': active,
  };
}

class HomeRowRow {
  HomeRowRow({
    this.id,
    required this.title,
    this.position = 0,
    this.seriesIds = const [],
    this.active = true,
  });

  int? id;
  String title;
  int position;
  List<String> seriesIds;
  bool active;

  factory HomeRowRow.fromJson(Map<String, dynamic> json) => HomeRowRow(
    id: json['id'] as int,
    title: json['title'] as String,
    position: json['position'] as int? ?? 0,
    seriesIds: _strings(json['series_ids']),
    active: json['active'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'position': position,
    'series_ids': seriesIds,
    'active': active,
  };
}
