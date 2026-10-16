import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/models.dart';
import 'hls_downloader.dart';

enum DownloadState { queued, waitingForWifi, downloading, done, failed }

/// One episode saved (or being saved) on the phone.
class DownloadItem {
  DownloadItem({
    required this.seriesId,
    required this.number,
    required this.seriesTitle,
    this.state = DownloadState.queued,
    this.bytes = 0,
    this.entry,
    this.subtitlesVtt,
    this.endsAt,
    this.error,
    this.savedAt,
    this.playableUntil,
  });

  final String seriesId;
  final int number;
  final String seriesTitle;
  DownloadState state;
  double progress = 0;
  int bytes;

  /// The playlist to play, relative to the downloads folder.
  String? entry;
  String? subtitlesVtt;
  Duration? endsAt;
  String? error;
  DateTime? savedAt;

  /// Set when the episode was only open because of a pass: the copy stops
  /// playing when the pass ends. Free and unlocked episodes play for good.
  DateTime? playableUntil;

  String get key => '$seriesId/$number';
  bool get isDone => state == DownloadState.done;
  bool get isActive =>
      state == DownloadState.queued ||
      state == DownloadState.waitingForWifi ||
      state == DownloadState.downloading;

  Map<String, dynamic> toJson() => {
    'series_id': seriesId,
    'number': number,
    'series_title': seriesTitle,
    'state': (isDone ? DownloadState.done : DownloadState.queued).name,
    'bytes': bytes,
    'entry': entry,
    'subtitles_vtt': subtitlesVtt,
    'ends_at_ms': endsAt?.inMilliseconds,
    'saved_at': savedAt?.toIso8601String(),
    'playable_until': playableUntil?.toIso8601String(),
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    final endsAt = json['ends_at_ms'] as int?;
    final savedAt = json['saved_at'] as String?;
    final until = json['playable_until'] as String?;
    return DownloadItem(
      seriesId: json['series_id'] as String,
      number: json['number'] as int,
      seriesTitle: json['series_title'] as String? ?? '',
      state: json['state'] == DownloadState.done.name
          ? DownloadState.done
          : DownloadState.queued,
      bytes: json['bytes'] as int? ?? 0,
      entry: json['entry'] as String?,
      subtitlesVtt: json['subtitles_vtt'] as String?,
      endsAt: endsAt == null ? null : Duration(milliseconds: endsAt),
      savedAt: savedAt == null ? null : DateTime.tryParse(savedAt),
      playableUntil: until == null ? null : DateTime.tryParse(until),
    );
  }
}

/// Whether the phone is on WiFi. [ConnectivityNetwork] on phones; a fake in
/// tests.
abstract class NetworkStatus {
  /// True on WiFi or a cable: connections the viewer does not pay for by the
  /// megabyte.
  Future<bool> isUnmetered();

  /// Fires when the connection changes.
  Stream<void> get changes;
}

class ConnectivityNetwork implements NetworkStatus {
  final _connectivity = Connectivity();

  @override
  Future<bool> isUnmetered() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
    } on Object {
      return false;
    }
  }

  @override
  Stream<void> get changes => _connectivity.onConnectivityChanged;
}

/// Looks up an episode with a fresh video link just before it downloads.
/// Throws if the viewer may not watch it (locked).
typedef EpisodeResolver = Future<Episode> Function(String seriesId, int number);

/// Keeps the list of downloads, saves them one at a time, waits for WiFi
/// when the viewer asked for that, and remembers everything across restarts
/// (`index.json` in [root]).
class DownloadManager extends ChangeNotifier {
  DownloadManager({
    required this.root,
    required this.resolve,
    required this.wifiOnly,
    required this.maxBitrate,
    NetworkStatus? network,
    HlsDownloader? downloader,
  }) : network = network ?? ConnectivityNetwork(),
       _downloader = downloader ?? HlsDownloader();

  final Directory root;
  final EpisodeResolver resolve;
  final bool Function() wifiOnly;
  final int Function() maxBitrate;
  final NetworkStatus network;
  final HlsDownloader _downloader;

  final Map<String, DownloadItem> _items = {};
  StreamSubscription<void>? _networkChanges;
  DownloadItem? _current;
  bool _cancelCurrent = false;
  bool _pumping = false;

  /// Everything, newest first within each series, series in title order.
  List<DownloadItem> get items {
    final list = _items.values.toList()
      ..sort((a, b) {
        final bySeries = a.seriesTitle.compareTo(b.seriesTitle);
        return bySeries != 0 ? bySeries : a.number.compareTo(b.number);
      });
    return list;
  }

  DownloadItem? item(String seriesId, int number) =>
      _items['$seriesId/$number'];

  int get totalBytes =>
      _items.values.where((i) => i.isDone).fold(0, (sum, i) => sum + i.bytes);

  int get doneCount => _items.values.where((i) => i.isDone).length;

  /// Reads the saved list and resumes anything unfinished.
  Future<void> load() async {
    try {
      final file = _indexFile;
      if (await file.exists()) {
        final list = jsonDecode(await file.readAsString()) as List;
        for (final raw in list) {
          final item = DownloadItem.fromJson(raw as Map<String, dynamic>);
          // A finished download whose files are gone is forgotten.
          if (item.isDone &&
              (item.entry == null ||
                  !await File('${root.path}/${item.entry}').exists())) {
            continue;
          }
          _items[item.key] = item;
        }
      }
    } on Object {
      // A damaged list is replaced by the next save.
    }
    _networkChanges = network.changes.listen((_) => resume());
    notifyListeners();
    unawaited(_pump());
  }

  /// The downloaded copy of an episode, ready to play without a connection.
  Episode? offlineEpisode(String seriesId, int number) {
    final item = _items['$seriesId/$number'];
    if (item == null || !item.isDone || item.entry == null) return null;
    final until = item.playableUntil;
    if (until != null && DateTime.now().isAfter(until)) return null;
    return Episode(
      seriesId: seriesId,
      number: number,
      videoUrl: Uri.file('${root.path}/${item.entry}').toString(),
      subtitlesVtt: item.subtitlesVtt,
      endsAt: item.endsAt,
    );
  }

  /// Adds episodes to the list. Ones already saved or waiting are skipped.
  /// [playableUntil] gives the pass end for episodes only open thanks to a
  /// pass. Returns how many were added.
  int add(
    Series series,
    Iterable<int> numbers, {
    DateTime? Function(int number)? playableUntil,
  }) {
    var added = 0;
    for (final number in numbers) {
      final existing = _items['${series.id}/$number'];
      if (existing != null && existing.state != DownloadState.failed) continue;
      _items['${series.id}/$number'] = DownloadItem(
        seriesId: series.id,
        number: number,
        seriesTitle: series.title,
        playableUntil: playableUntil?.call(number),
      );
      added++;
    }
    if (added > 0) {
      notifyListeners();
      unawaited(_save());
      unawaited(_pump());
    }
    return added;
  }

  void retry(String seriesId, int number) {
    final item = _items['$seriesId/$number'];
    if (item == null || item.state != DownloadState.failed) return;
    item
      ..state = DownloadState.queued
      ..error = null;
    notifyListeners();
    unawaited(_pump());
  }

  /// Deletes a download, or stops it if it is in progress.
  Future<void> remove(String seriesId, int number) async {
    final item = _items.remove('$seriesId/$number');
    if (item == null) return;
    if (identical(item, _current)) _cancelCurrent = true;
    notifyListeners();
    await _deleteFiles(item);
    await _save();
  }

  Future<void> removeAll() async {
    if (_current != null) _cancelCurrent = true;
    _items.clear();
    notifyListeners();
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } on Object {
      // Nothing more to do; leftover files are overwritten later.
    }
    await _save();
  }

  /// Looks again at the connection and the WiFi-only setting.
  void resume() {
    for (final item in _items.values) {
      if (item.state == DownloadState.waitingForWifi) {
        item.state = DownloadState.queued;
      }
    }
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (true) {
        final next = _items.values
            .where((i) => i.state == DownloadState.queued)
            .firstOrNull;
        if (next == null) break;
        if (wifiOnly() && !await network.isUnmetered()) {
          for (final item in _items.values) {
            if (item.state == DownloadState.queued) {
              item.state = DownloadState.waitingForWifi;
            }
          }
          notifyListeners();
          break;
        }
        await _download(next);
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _download(DownloadItem item) async {
    _current = item;
    _cancelCurrent = false;
    item
      ..state = DownloadState.downloading
      ..progress = 0;
    notifyListeners();
    try {
      final episode = await resolve(item.seriesId, item.number);
      final url = episode.videoUrl;
      if (url == null) {
        throw const DownloadException('Unlock this episode to download it.');
      }
      var lastShown = 0.0;
      final result = await _downloader.download(
        source: Uri.parse(url),
        dir: _dirFor(item),
        maxBitrate: maxBitrate(),
        limit: episode.endsAt,
        isCancelled: () => _cancelCurrent,
        onProgress: (p) {
          item.progress = p;
          // Redraw at most every 5%, to keep cheap phones smooth.
          if (p - lastShown >= 0.05 || p >= 1) {
            lastShown = p;
            notifyListeners();
          }
        },
      );
      item
        ..state = DownloadState.done
        ..bytes = result.bytes
        ..entry = result.entry.path.substring(root.path.length + 1)
        ..subtitlesVtt = episode.subtitlesVtt
        ..endsAt = episode.endsAt
        ..savedAt = DateTime.now();
    } on DownloadCancelled {
      await _deleteFiles(item);
    } on DownloadException catch (e) {
      _fail(item, e.message);
    } on FileSystemException {
      _fail(item, 'Could not save the episode. Is the phone\'s storage full?');
    } on Object catch (e) {
      // e.g. the server refused to give the link.
      _fail(item, e.toString());
    } finally {
      _current = null;
      if (_items.containsKey(item.key)) {
        await _save();
      } else {
        // Deleted while it was finishing: clear what was written.
        await _deleteFiles(item);
      }
      notifyListeners();
    }
  }

  void _fail(DownloadItem item, String message) {
    item
      ..state = DownloadState.failed
      ..error = message;
  }

  Directory _dirFor(DownloadItem item) =>
      Directory('${root.path}/${item.seriesId}/${item.number}');

  Future<void> _deleteFiles(DownloadItem item) async {
    try {
      final dir = _dirFor(item);
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Object {
      // Already gone, or the folder is busy; nothing else to do.
    }
  }

  File get _indexFile => File('${root.path}/index.json');

  Future<void> _save() async {
    try {
      await root.create(recursive: true);
      await _indexFile.writeAsString(
        jsonEncode([for (final i in _items.values) i.toJson()]),
      );
    } on Object {
      // Saving the list is best-effort; the files themselves are intact.
    }
  }

  @override
  void dispose() {
    _networkChanges?.cancel();
    _cancelCurrent = true;
    super.dispose();
  }
}
