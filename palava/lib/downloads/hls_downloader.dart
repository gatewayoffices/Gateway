import 'dart:io';

import 'package:http/http.dart' as http;

/// Why a download could not finish.
class DownloadException implements Exception {
  const DownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the viewer cancels (or deletes) a download in progress.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// A finished download: [entry] is the playlist to hand to the player.
class HlsDownload {
  const HlsDownload({required this.entry, required this.bytes});

  final File entry;
  final int bytes;
}

/// Saves an HLS episode (the same streams the app plays online) to the
/// phone so it can play without a connection.
///
/// Only one quality is kept: the best one at or under [maxBitrate] (the Data
/// saver limit), with one stereo audio track. Only the pieces up to [limit]
/// (where the episode ends) are fetched. Locked or encrypted streams are not
/// supported. Files are written to a temporary folder and moved into [dir]
/// only once everything has arrived, so a half-finished download never looks
/// complete.
class HlsDownloader {
  HlsDownloader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<HlsDownload> download({
    required Uri source,
    required Directory dir,
    required int maxBitrate,
    Duration? limit,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final work = Directory('${dir.path}.part');
    if (await work.exists()) await work.delete(recursive: true);
    await work.create(recursive: true);
    try {
      final job = _Job(
        client: _client,
        work: work,
        isCancelled: isCancelled ?? () => false,
        onProgress: onProgress,
      );
      final entryName = await job.run(source, maxBitrate, limit);
      if (await dir.exists()) await dir.delete(recursive: true);
      await work.rename(dir.path);
      return HlsDownload(
        entry: File('${dir.path}/$entryName'),
        bytes: job.bytes,
      );
    } catch (_) {
      if (await work.exists()) await work.delete(recursive: true);
      rethrow;
    }
  }
}

class _Job {
  _Job({
    required this.client,
    required this.work,
    required this.isCancelled,
    required this.onProgress,
  });

  final http.Client client;
  final Directory work;
  final bool Function() isCancelled;
  final void Function(double progress)? onProgress;

  int bytes = 0;
  int _done = 0;
  int _total = 0;

  /// Downloads everything and returns the name of the playlist to play.
  Future<String> run(Uri source, int maxBitrate, Duration? limit) async {
    final text = await _text(source);
    if (_isMediaPlaylist(text)) {
      final media = _plan(source, text, 'v', limit);
      _total = media.files.length;
      await _fetchAll(media);
      await _write('video.m3u8', media.playlist);
      return 'video.m3u8';
    }

    final master = _Master.parse(text);
    final variant = master.pick(maxBitrate);
    if (variant == null) {
      throw const DownloadException('This episode has no playable video.');
    }
    final videoUri = source.resolve(variant.uri);
    final video = _plan(videoUri, await _text(videoUri), 'v', limit);

    _Plan? audio;
    final rendition = master.audioFor(variant);
    if (rendition != null) {
      final audioUri = source.resolve(rendition);
      audio = _plan(audioUri, await _text(audioUri), 'a', limit);
    }

    _total = video.files.length + (audio?.files.length ?? 0);
    await _fetchAll(video);
    if (audio != null) await _fetchAll(audio);

    await _write('video.m3u8', video.playlist);
    if (audio != null) await _write('audio.m3u8', audio.playlist);
    await _write('index.m3u8', variant.localMaster(withAudio: audio != null));
    return 'index.m3u8';
  }

  static bool _isMediaPlaylist(String text) =>
      text.contains('#EXTINF') || text.contains('#EXT-X-TARGETDURATION');

  /// Reads a media playlist, keeps the pieces up to [limit], and rewrites
  /// every address to a local file name.
  _Plan _plan(Uri base, String text, String prefix, Duration? limit) {
    final out = StringBuffer();
    final files = <String, Uri>{};
    final names = <String, String>{};
    var seconds = 0.0;
    var stop = false;

    String local(String uri) {
      final resolved = base.resolve(uri);
      return names.putIfAbsent(resolved.toString(), () {
        final path = resolved.path;
        final dot = path.lastIndexOf('.');
        final ext = dot > path.lastIndexOf('/') ? path.substring(dot) : '';
        final name = '$prefix${names.length}$ext';
        files[name] = resolved;
        return name;
      });
    }

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXT-X-ENDLIST')) continue;
      if (line.startsWith('#EXT-X-KEY')) {
        final method = _attributes(line)['METHOD'];
        if (method != null && method != 'NONE') {
          throw const DownloadException(
            'This episode is protected and cannot be downloaded.',
          );
        }
      }
      if (line.startsWith('#EXT-X-MAP')) {
        final uri = _attributes(line)['URI'];
        if (uri != null) {
          out.writeln(line.replaceFirst('"$uri"', '"${local(uri)}"'));
          continue;
        }
      }
      if (line.startsWith('#EXTINF')) {
        // The pieces so far already reach the end of the episode.
        if (stop) break;
        final value = line.substring('#EXTINF:'.length).split(',').first;
        seconds += double.tryParse(value.trim()) ?? 0;
      }
      if (line.startsWith('#')) {
        out.writeln(line);
        continue;
      }
      // A piece of video or audio.
      out.writeln(local(line));
      if (limit != null && seconds * 1000 >= limit.inMilliseconds) stop = true;
    }
    out.writeln('#EXT-X-ENDLIST');
    return _Plan(out.toString(), files);
  }

  Future<void> _fetchAll(_Plan plan) async {
    for (final entry in plan.files.entries) {
      if (isCancelled()) throw const DownloadCancelled();
      final response = await _get(entry.value);
      await File('${work.path}/${entry.key}').writeAsBytes(response.bodyBytes);
      bytes += response.bodyBytes.length;
      _done++;
      onProgress?.call(_total == 0 ? 1 : _done / _total);
    }
  }

  Future<String> _text(Uri uri) async {
    if (isCancelled()) throw const DownloadCancelled();
    return (await _get(uri)).body;
  }

  Future<http.Response> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await client.get(uri).timeout(const Duration(seconds: 30));
    } on Exception {
      throw const DownloadException(
        'The connection was lost. The download will try again.',
      );
    }
    if (response.statusCode != 200) {
      throw DownloadException(
        'The video server refused the download (${response.statusCode}).',
      );
    }
    return response;
  }

  Future<void> _write(String name, String content) =>
      File('${work.path}/$name').writeAsString(content);
}

class _Plan {
  _Plan(this.playlist, this.files);

  final String playlist;

  /// Local file name → where to fetch it from.
  final Map<String, Uri> files;
}

class _Variant {
  _Variant(this.attributes, this.uri);

  final Map<String, String> attributes;
  final String uri;

  int get bitrate =>
      int.tryParse(attributes['AVERAGE-BANDWIDTH'] ?? '') ??
      int.tryParse(attributes['BANDWIDTH'] ?? '') ??
      0;

  int get peak => int.tryParse(attributes['BANDWIDTH'] ?? '') ?? bitrate;

  String get codecs => attributes['CODECS'] ?? '';

  /// Surround-sound audio many cheap phones cannot play.
  bool get hasSurround => codecs.contains('ac-3') || codecs.contains('ec-3');

  String localMaster({required bool withAudio}) {
    final info = [
      'BANDWIDTH=$peak',
      if (attributes['AVERAGE-BANDWIDTH'] != null)
        'AVERAGE-BANDWIDTH=${attributes['AVERAGE-BANDWIDTH']}',
      if (codecs.isNotEmpty) 'CODECS="$codecs"',
      if (attributes['RESOLUTION'] != null)
        'RESOLUTION=${attributes['RESOLUTION']}',
      if (withAudio) 'AUDIO="audio"',
    ].join(',');
    return [
      '#EXTM3U',
      '#EXT-X-VERSION:6',
      if (withAudio)
        '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Audio",'
            'DEFAULT=YES,AUTOSELECT=YES,URI="audio.m3u8"',
      '#EXT-X-STREAM-INF:$info',
      'video.m3u8',
      '',
    ].join('\n');
  }
}

class _Master {
  _Master(this.variants, this.audio);

  final List<_Variant> variants;

  /// Audio renditions: attributes of each #EXT-X-MEDIA TYPE=AUDIO line.
  final List<Map<String, String>> audio;

  static _Master parse(String text) {
    final variants = <_Variant>[];
    final audio = <Map<String, String>>[];
    Map<String, String>? pending;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        pending = _attributes(line);
      } else if (line.startsWith('#EXT-X-MEDIA:')) {
        final attrs = _attributes(line);
        if (attrs['TYPE'] == 'AUDIO' && attrs['URI'] != null) audio.add(attrs);
      } else if (!line.startsWith('#') && pending != null) {
        variants.add(_Variant(pending, line));
        pending = null;
      }
    }
    return _Master(variants, audio);
  }

  /// The best quality at or under [maxBitrate], else the smallest one.
  _Variant? pick(int maxBitrate) {
    var options = variants.where((v) => !v.hasSurround).toList();
    if (options.isEmpty) options = [...variants];
    if (options.isEmpty) return null;
    options.sort((a, b) => a.bitrate.compareTo(b.bitrate));
    final affordable = options.where((v) => v.bitrate <= maxBitrate);
    return affordable.isEmpty ? options.first : affordable.last;
  }

  /// The audio track to download with [variant]: its group's default,
  /// preferring stereo.
  String? audioFor(_Variant variant) {
    final group = variant.attributes['AUDIO'];
    if (group == null) return null;
    final inGroup = audio.where((a) => a['GROUP-ID'] == group).toList();
    if (inGroup.isEmpty) return null;
    int score(Map<String, String> a) =>
        (a['DEFAULT'] == 'YES' ? 2 : 0) + (a['CHANNELS'] == '2' ? 1 : 0);
    inGroup.sort((a, b) => score(b).compareTo(score(a)));
    return inGroup.first['URI'];
  }
}

/// Reads `KEY=value,KEY="quoted, value"` attribute lists.
Map<String, String> _attributes(String line) {
  final colon = line.indexOf(':');
  final body = colon < 0 ? '' : line.substring(colon + 1);
  final result = <String, String>{};
  final pattern = RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)');
  for (final m in pattern.allMatches(body)) {
    var value = m.group(2)!;
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.substring(1, value.length - 1);
    }
    result[m.group(1)!] = value;
  }
  return result;
}
