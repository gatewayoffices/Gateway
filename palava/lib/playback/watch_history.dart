import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Where the viewer stopped in one series.
class WatchEntry {
  const WatchEntry({
    required this.seriesId,
    required this.episodeNumber,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final String seriesId;
  final int episodeNumber;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  double get progress => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  /// Close enough to the end that "resume" should start the next episode.
  bool get isFinished => progress >= 0.95;

  Map<String, Object> toJson() => {
    'series': seriesId,
    'episode': episodeNumber,
    'position': position.inMilliseconds,
    'duration': duration.inMilliseconds,
    'updated': updatedAt.millisecondsSinceEpoch,
  };

  static WatchEntry fromJson(Map<String, dynamic> json) => WatchEntry(
    seriesId: json['series'] as String,
    episodeNumber: json['episode'] as int,
    position: Duration(milliseconds: json['position'] as int),
    duration: Duration(milliseconds: json['duration'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated'] as int),
  );
}

/// Watch history kept on the phone. Milestone 4 syncs it to Supabase so it
/// follows the viewer across devices.
class WatchHistory {
  WatchHistory([this._prefs]) {
    final raw = _prefs?.getString(_key);
    if (raw == null) return;
    try {
      for (final item in jsonDecode(raw) as List<dynamic>) {
        final entry = WatchEntry.fromJson(item as Map<String, dynamic>);
        _entries[entry.seriesId] = entry;
      }
    } on FormatException {
      // Corrupt data: start fresh rather than crash.
    } on TypeError {
      // Data from an older app version: start fresh.
    }
  }

  static const _key = 'watch_history_v1';

  final SharedPreferences? _prefs;
  final Map<String, WatchEntry> _entries = {};

  WatchEntry? lastFor(String seriesId) => _entries[seriesId];

  /// Most recently watched first.
  List<WatchEntry> get recent =>
      _entries.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  bool get isEmpty => _entries.isEmpty;

  void record(WatchEntry entry) {
    _entries[entry.seriesId] = entry;
    _prefs?.setString(
      _key,
      jsonEncode([for (final e in _entries.values) e.toJson()]),
    );
  }
}
