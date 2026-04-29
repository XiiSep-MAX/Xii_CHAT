import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'image_download_metadata.dart';
import 'image_download_progress.dart';
import 'models.dart';

Future<void> downloadImagePlatform(
  GeneratedImageAsset image, {
  BuildContext? context,
  void Function(ImageDownloadProgress progress)? onProgress,
}) async {
  final messenger = context == null ? null : ScaffoldMessenger.maybeOf(context);

  try {
    final downloadDir = await _resolveDownloadsDirectory();
    if (downloadDir == null) {
      _showSnackBar(messenger, '无法定位下载目录，请检查系统配置。');
      return;
    }

    if (image.hasBytes) {
      final metadata = resolveImageDownloadMetadata(
        fileName: image.fileName,
        imageUrl: image.imageUrl,
        contentType: image.mimeType,
        bytes: image.bytes,
      );
      onProgress?.call(
        ImageDownloadProgress(
          phase: ImageDownloadPhase.finalizing,
          message: '正在保存图片...',
          downloadedBytes: image.bytes!.length,
          totalBytes: image.bytes!.length,
        ),
      );
      final file = await _resolveAvailableFile(downloadDir, metadata.fileName);
      await file.writeAsBytes(image.bytes!, flush: true);
      onProgress?.call(
        ImageDownloadProgress(
          phase: ImageDownloadPhase.completed,
          message: '图片保存完成',
          downloadedBytes: image.bytes!.length,
          totalBytes: image.bytes!.length,
        ),
      );
      _showSnackBar(messenger, '图片已保存：${path.basename(file.path)}');
      return;
    }

    final uri = Uri.tryParse(image.imageUrl ?? '');
    if (uri == null) {
      _showSnackBar(messenger, '图片地址无效，无法下载。');
      return;
    }

    onProgress?.call(
      const ImageDownloadProgress(
        phase: ImageDownloadPhase.preparing,
        message: '正在连接图片服务器...',
        downloadedBytes: 0,
        totalBytes: null,
      ),
    );

    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        _showSnackBar(messenger, '下载失败：HTTP ${response.statusCode}');
        return;
      }

      final totalBytes =
          response.contentLength != null && response.contentLength! > 0
              ? response.contentLength
              : null;
      final bytesBuffer = BytesBuilder(copy: false);
      var downloadedBytes = 0;

      onProgress?.call(
        ImageDownloadProgress(
          phase: ImageDownloadPhase.downloading,
          message: '正在下载图片...',
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
        ),
      );

      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        bytesBuffer.add(chunk);
        downloadedBytes += chunk.length;
        onProgress?.call(
          ImageDownloadProgress(
            phase: ImageDownloadPhase.downloading,
            message: '正在下载图片...',
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
          ),
        );
      }

      final bodyBytes = bytesBuffer.takeBytes();
      final metadata = resolveImageDownloadMetadata(
        fileName: image.fileName,
        imageUrl: image.imageUrl,
        contentType: response.headers['content-type'] ?? image.mimeType,
        bytes: bodyBytes,
      );
      onProgress?.call(
        ImageDownloadProgress(
          phase: ImageDownloadPhase.finalizing,
          message: '正在保存图片...',
          downloadedBytes: bodyBytes.length,
          totalBytes: totalBytes ?? bodyBytes.length,
        ),
      );
      final file = await _resolveAvailableFile(downloadDir, metadata.fileName);
      await file.writeAsBytes(bodyBytes, flush: true);
      onProgress?.call(
        ImageDownloadProgress(
          phase: ImageDownloadPhase.completed,
          message: '图片保存完成',
          downloadedBytes: bodyBytes.length,
          totalBytes: totalBytes ?? bodyBytes.length,
        ),
      );
      _showSnackBar(messenger, '图片已保存：${path.basename(file.path)}');
    } finally {
      client.close();
    }
  } on SocketException {
    _showSnackBar(messenger, '下载失败：网络连接异常。');
  } on HttpException catch (e) {
    _showSnackBar(messenger, '下载失败：${e.message}');
  } catch (e) {
    _showSnackBar(messenger, '下载失败：$e');
  }
}

void _showSnackBar(ScaffoldMessengerState? messenger, String message) {
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<Directory?> _resolveDownloadsDirectory() async {
  final downloadsDir = await getDownloadsDirectory();
  if (downloadsDir != null) {
    await downloadsDir.create(recursive: true);
    return downloadsDir;
  }

  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile == null || userProfile.isEmpty) {
    return null;
  }

  final fallbackDir = Directory(path.join(userProfile, 'Downloads'));
  await fallbackDir.create(recursive: true);
  return fallbackDir;
}

Future<File> _resolveAvailableFile(Directory directory, String fileName) async {
  final sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  final extension = path.extension(sanitized);
  final baseName = extension.isEmpty
      ? sanitized
      : sanitized.substring(0, sanitized.length - extension.length);

  var candidate = File(path.join(directory.path, sanitized));
  var counter = 1;
  while (await candidate.exists()) {
    candidate = File(
      path.join(directory.path, '${baseName}_$counter$extension'),
    );
    counter++;
  }

  return candidate;
}
