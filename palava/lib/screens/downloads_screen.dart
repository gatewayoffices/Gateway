import 'package:flutter/material.dart';

import '../data/models.dart';
import '../downloads/download_manager.dart';
import '../state/app_state.dart';
import '../theme/palava_colors.dart';
import '../widgets/common.dart';
import 'player_screen.dart';

/// "6.2 MB", "820 KB".
String formatBytes(int bytes) {
  if (bytes >= 1000 * 1000 * 1000) {
    return '${(bytes / 1e9).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1000 * 1000) return '${(bytes / 1e6).toStringAsFixed(1)} MB';
  return '${(bytes / 1000).ceil()} KB';
}

/// Lets the viewer save episodes of [series] on the phone.
Future<void> showDownloadSheet(BuildContext context, Series series) {
  final manager = AppStateScope.read(context).downloads;
  if (manager == null) {
    showSampleMessage(context, 'Downloads are not available on this device.');
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DownloadSheet(series: series, manager: manager),
  );
}

class _DownloadSheet extends StatelessWidget {
  const _DownloadSheet({required this.series, required this.manager});

  final Series series;
  final DownloadManager manager;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final available = [
          for (var n = 1; n <= series.episodeCount; n++)
            if (state.isUnlocked(series, n) &&
                (manager.item(series.id, n) == null ||
                    manager.item(series.id, n)!.state == DownloadState.failed))
              n,
        ];
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Download ${series.title}',
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Saved episodes play without using data. '
                  '${state.wifiOnlyDownloads ? 'They download over WiFi only '
                            '(you can change this in Profile).' : 'They will also download on mobile data.'}',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: available.isEmpty
                      ? null
                      : () => state.downloadSeries(series),
                  icon: const Icon(Icons.download),
                  label: Text(
                    available.isEmpty
                        ? 'All open episodes are saved'
                        : 'Download all open episodes (${available.length})',
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: series.episodeCount,
                    itemBuilder: (context, i) => _EpisodeRow(
                      series: series,
                      number: i + 1,
                      manager: manager,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.series,
    required this.number,
    required this.manager,
  });

  final Series series;
  final int number;
  final DownloadManager manager;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final item = manager.item(series.id, number);
    final locked = item == null && !state.isUnlocked(series, number);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 52,
      title: Text('Episode $number'),
      subtitle: Text(
        locked ? 'Unlock to download' : _statusText(item),
        style: TextStyle(
          color: item?.state == DownloadState.failed
              ? PalavaColors.ember
              : PalavaColors.textQuiet,
        ),
      ),
      trailing: locked
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.lock, color: PalavaColors.gold),
            )
          : _StatusAction(
              item: item,
              onDownload: () => state.downloadEpisode(series, number),
              manager: manager,
            ),
    );
  }
}

String _statusText(DownloadItem? item) => switch (item?.state) {
  null => 'Not downloaded',
  DownloadState.queued => 'Waiting to download',
  DownloadState.waitingForWifi => 'Waiting for WiFi',
  DownloadState.downloading => 'Downloading ${(item!.progress * 100).round()}%',
  DownloadState.done => 'Saved  ·  ${formatBytes(item!.bytes)}',
  DownloadState.failed => item!.error ?? 'Download failed',
};

/// Download, progress, delete or retry, depending on [item].
class _StatusAction extends StatelessWidget {
  const _StatusAction({
    required this.item,
    required this.onDownload,
    required this.manager,
  });

  final DownloadItem? item;
  final VoidCallback onDownload;
  final DownloadManager manager;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    if (item == null) {
      return IconButton(
        tooltip: 'Download',
        icon: const Icon(Icons.download_outlined),
        onPressed: onDownload,
      );
    }
    void remove() => manager.remove(item.seriesId, item.number);
    return switch (item.state) {
      DownloadState.downloading => IconButton(
        tooltip: 'Stop download',
        onPressed: remove,
        icon: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            value: item.progress == 0 ? null : item.progress,
            strokeWidth: 2.5,
          ),
        ),
      ),
      DownloadState.failed => IconButton(
        tooltip: 'Try again',
        icon: const Icon(Icons.refresh),
        onPressed: () => manager.retry(item.seriesId, item.number),
      ),
      DownloadState.done => IconButton(
        tooltip: 'Delete download',
        icon: const Icon(Icons.delete_outline),
        onPressed: remove,
      ),
      DownloadState.queued || DownloadState.waitingForWifi => IconButton(
        tooltip: 'Cancel',
        icon: const Icon(Icons.close),
        onPressed: remove,
      ),
    };
  }
}

/// Everything saved on the phone (Profile > Downloads).
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  Future<void> _deleteAll(BuildContext context, DownloadManager manager) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all downloads?'),
        content: const Text(
          'This frees the space on your phone. You can download them again '
          'later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (sure == true) await manager.removeAll();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final manager = state.downloads;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: manager == null
          ? const Center(child: Text('Downloads are not available here.'))
          : ListenableBuilder(
              listenable: manager,
              builder: (context, _) {
                final items = manager.items;
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No downloads yet. Open a series and tap Download to '
                        'watch it later without using data.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge,
                      ),
                    ),
                  );
                }
                final bySeries = <String, List<DownloadItem>>{};
                for (final item in items) {
                  bySeries.putIfAbsent(item.seriesId, () => []).add(item);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(
                      '${manager.doneCount} episode'
                      '${manager.doneCount == 1 ? '' : 's'} saved  ·  '
                      '${formatBytes(manager.totalBytes)} on this phone',
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.wifiOnlyDownloads
                          ? 'Downloads use WiFi only.'
                          : 'Downloads also use mobile data.',
                      style: textTheme.bodySmall,
                    ),
                    for (final entry in bySeries.entries) ...[
                      const SizedBox(height: 20),
                      Text(
                        entry.value.first.seriesTitle,
                        style: textTheme.titleLarge,
                      ),
                      for (final item in entry.value)
                        _SavedRow(item: item, manager: manager),
                    ],
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => _deleteAll(context, manager),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete all downloads'),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.item, required this.manager});

  final DownloadItem item;
  final DownloadManager manager;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final series = state.catalog.seriesById(item.seriesId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 52,
      title: Text('Episode ${item.number}'),
      subtitle: Text(
        _statusText(item),
        style: TextStyle(
          color: item.state == DownloadState.failed
              ? PalavaColors.ember
              : PalavaColors.textQuiet,
        ),
      ),
      onTap: item.isDone && series != null
          ? () => openPlayer(context, series, episode: item.number)
          : null,
      trailing: _StatusAction(item: item, onDownload: () {}, manager: manager),
    );
  }
}
