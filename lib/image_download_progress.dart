enum ImageDownloadPhase {
  preparing,
  downloading,
  finalizing,
  completed,
}

class ImageDownloadProgress {
  final ImageDownloadPhase phase;
  final String message;
  final int downloadedBytes;
  final int? totalBytes;

  const ImageDownloadProgress({
    required this.phase,
    required this.message,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  bool get hasKnownTotal => totalBytes != null && totalBytes! > 0;

  double? get progress {
    if (!hasKnownTotal) return null;
    return (downloadedBytes / totalBytes!).clamp(0.0, 1.0);
  }

  String get progressLabel {
    if (!hasKnownTotal) {
      return '已下载 ${_formatBytes(downloadedBytes)}';
    }

    final percent = ((progress ?? 0) * 100).toStringAsFixed(0);
    return '$percent% · ${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes!)}';
  }

  static String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final fractionDigits = value >= 100 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
  }
}
