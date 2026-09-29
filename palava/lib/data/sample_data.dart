import 'package:flutter/material.dart';

import 'models.dart';

/// Hard-coded sample content used until the backend exists (Milestone 4).
/// All series here are made-up placeholders for layout and testing.
class SampleData {
  SampleData._();

  static const config = AppConfig(
    freeEpisodeCount: 8,
    unlockCostCoins: 30,
    freeAdsPerDay: 3,
    dataSaverMaxBitrate: 800000,
    priceLabel: '[PRICE]',
    coinPacks: [
      CoinPack(coins: 100),
      CoinPack(coins: 300, bonusCoins: 20),
      CoinPack(coins: 600, bonusCoins: 60),
      CoinPack(coins: 1200, bonusCoins: 150),
    ],
    passes: [
      Pass(name: 'Day pass', description: 'Every episode, 24 hours'),
      Pass(name: 'Week pass', description: 'Every episode, 7 days'),
    ],
    homeRows: [
      HomeRow(
        title: 'Trending in Monrovia',
        seriesIds: ['waterside', 'bride-price', 'sinkor-nights', 'palm-wine'],
      ),
      HomeRow(
        title: 'New this week',
        seriesIds: ['diaspora-daughter', 'lagos-contract', 'second-wife'],
      ),
      HomeRow(
        title: 'Family and romance',
        seriesIds: ['mama-kitchen', 'bride-price', 'diaspora-daughter'],
      ),
    ],
  );

  static const featuredSeriesId = 'bride-price';

  static const series = <Series>[
    Series(
      id: 'bride-price',
      title: 'The Bride Price',
      tagline: 'Two families. One wedding. Too many secrets.',
      synopsis:
          'Weeks before her wedding in Monrovia, Hawa discovers that the '
          'bride price her fiance\'s family paid came from a debt her own '
          'father never told her about. Now both families want something '
          'from her, and the wedding clock is ticking.',
      genres: ['Romance', 'Family'],
      episodeCount: 40,
      language: 'English',
      ageRating: '13+',
      posterColors: [Color(0xFF8C2F1B), Color(0xFF2B1209)],
    ),
    Series(
      id: 'waterside',
      title: 'Waterside Boys',
      tagline: 'The market runs on favours. Favours run out.',
      synopsis:
          'Three friends who grew up hustling in Waterside Market get one '
          'chance at a big deal. When the money goes missing, trust is the '
          'first thing to disappear.',
      genres: ['Crime', 'Thriller'],
      episodeCount: 32,
      language: 'English',
      ageRating: '16+',
      posterColors: [Color(0xFF1F4E5A), Color(0xFF0E1A1F)],
    ),
    Series(
      id: 'diaspora-daughter',
      title: 'Diaspora Daughter',
      tagline: 'She came home for a funeral. She stayed for the truth.',
      synopsis:
          'Raised in Minnesota, Ada returns to Liberia to bury the '
          'grandmother she barely knew, and finds a will that names her '
          'the owner of land the whole town is fighting over.',
      genres: ['Drama', 'Mystery'],
      episodeCount: 36,
      language: 'English',
      ageRating: '13+',
      posterColors: [Color(0xFF6B4A1E), Color(0xFF1E140A)],
    ),
    Series(
      id: 'sinkor-nights',
      title: 'Sinkor Nights',
      tagline: 'Love after midnight has rules.',
      synopsis:
          'A nightclub singer and a young doctor keep meeting by accident on '
          'Tubman Boulevard. Neither of them is who the other thinks.',
      genres: ['Romance'],
      episodeCount: 28,
      language: 'English',
      ageRating: '16+',
      posterColors: [Color(0xFF4A1F4E), Color(0xFF160B18)],
    ),
    Series(
      id: 'palm-wine',
      title: 'Palm Wine and Secrets',
      tagline: 'Every village keeps one. This one keeps many.',
      synopsis:
          'When a stranger opens a palm wine bar in a quiet Bong County town, '
          'old secrets start pouring out with every cup.',
      genres: ['Mystery', 'Drama'],
      episodeCount: 30,
      language: 'English',
      ageRating: '13+',
      posterColors: [Color(0xFF3E5A1F), Color(0xFF12190A)],
    ),
    Series(
      id: 'lagos-contract',
      title: 'The Lagos Contract',
      tagline: 'Sign here. Lose everything.',
      synopsis:
          'A young Liberian lawyer lands a dream job in Lagos, until she '
          'realises the contract she drafted is being used to take over her '
          'own family\'s business.',
      genres: ['Thriller', 'Drama'],
      episodeCount: 34,
      language: 'English',
      ageRating: '13+',
      posterColors: [Color(0xFF5A3A1F), Color(0xFF1A0F07)],
    ),
    Series(
      id: 'second-wife',
      title: 'The Chief\'s Second Wife',
      tagline: 'She married into power. Now she wants it.',
      synopsis:
          'Musu marries an ageing town chief for security. When he falls ill, '
          'she has to outplay his first wife, his sons and the elders to '
          'protect her daughter.',
      genres: ['Drama', 'Family'],
      episodeCount: 45,
      language: 'English',
      ageRating: '16+',
      posterColors: [Color(0xFF7A5A12), Color(0xFF221806)],
    ),
    Series(
      id: 'mama-kitchen',
      title: 'Mama Sia\'s Kitchen',
      tagline: 'The best cookshop in Paynesville. The loudest family too.',
      synopsis:
          'Mama Sia runs the most popular cookshop in Paynesville with her '
          'four grown children, who all want to run it differently.',
      genres: ['Comedy', 'Family'],
      episodeCount: 24,
      language: 'English',
      ageRating: 'All ages',
      posterColors: [Color(0xFF9A4A16), Color(0xFF2A1405)],
    ),
  ];

  static const continueWatching = <ContinueWatching>[
    ContinueWatching(seriesId: 'waterside', episodeNumber: 5, progress: 0.62),
    ContinueWatching(seriesId: 'bride-price', episodeNumber: 12, progress: 0.3),
    ContinueWatching(
      seriesId: 'diaspora-daughter',
      episodeNumber: 2,
      progress: 0.85,
    ),
  ];

  /// Series shown, one after another, in the For You feed.
  static const forYouSeriesIds = [
    'sinkor-nights',
    'waterside',
    'bride-price',
    'palm-wine',
    'second-wife',
    'lagos-contract',
  ];

  static const genres = [
    'Romance',
    'Drama',
    'Family',
    'Thriller',
    'Crime',
    'Mystery',
    'Comedy',
  ];

  static Series seriesById(String id) => series.firstWhere((s) => s.id == id);

  /// Free public HLS test streams (Google's Shaka Player demo assets). They
  /// are landscape and not African dramas; they only prove the player works.
  static const _testStreams = [
    'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8',
    'https://storage.googleapis.com/shaka-demo-assets/bbb-dark-truths-hls/hls.m3u8',
    'https://storage.googleapis.com/shaka-demo-assets/apple-advanced-stream-ts/master.m3u8',
  ];

  /// Every sample episode stops here so autoplay-next can be tried quickly.
  static const sampleEpisodeLength = Duration(seconds: 75);

  static List<Episode> episodesFor(Series series) => [
    for (var n = 1; n <= series.episodeCount; n++)
      Episode(
        seriesId: series.id,
        number: n,
        videoUrl: _testStreams[(n - 1) % _testStreams.length],
        subtitlesVtt: _sampleSubtitles,
        endsAt: sampleEpisodeLength,
      ),
  ];

  static const _sampleSubtitleLines = [
    'Where were you last night?',
    'You don\'t want to know.',
    'Everybody in this town has a secret.',
    'Then tell me yours.',
    'Not here. Not now.',
    'If Mama finds out...',
    'She won\'t. Unless you tell her.',
    'I\'m tired of lying for you.',
    'Then stop.',
    'It\'s too late for that.',
    'Someone is at the door.',
    'Don\'t open it.',
  ];

  static final String _sampleSubtitles = () {
    final buffer = StringBuffer('WEBVTT\n\n');
    for (var i = 0; i < _sampleSubtitleLines.length; i++) {
      buffer
        ..writeln('${_vttTime(i * 6 + 1)} --> ${_vttTime(i * 6 + 5)}')
        ..writeln(_sampleSubtitleLines[i])
        ..writeln();
    }
    return buffer.toString();
  }();

  static String _vttTime(int seconds) =>
      '00:${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}.000';
}
