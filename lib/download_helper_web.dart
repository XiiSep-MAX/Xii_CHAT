import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
    late final ResolvedImageDownloadMetadata metadata;
    late final String href;
    var shouldRevokeObjectUrl = false;

    if (image.hasBytes) {
      onProgress?.call(
        ImageDownloadProgress(
          phase: ImageDownloadPhase.finalizing,
          message: '正在整理图片...',
          downloadedBytes: image.bytes!.length,
          totalBytes: image.bytes!.length,
        ),
      );
      metadata = resolveImageDownloadMetadata(
        fileName: image.fileName,
        imageUrl: image.imageUrl,
        contentType: image.mimeType,
        bytes: image.bytes,
      );
      href = html.Url.createObjectUrlFromBlob(
        html.Blob([image.bytes], metadata.mimeType),
      );
      shouldRevokeObjectUrl = true;
      onProgress?.call(
        ImageDownloadProgress(
          phase: ImageDownloadPhase.completed,
          message: '图片已准备好',
          downloadedBytes: image.bytes!.length,
          totalBytes: image.bytes!.length,
        ),
      );
    } else {
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
        final bytes = BytesBuilder(copy: false);
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
          bytes.add(chunk);
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

        final bodyBytes = bytes.takeBytes();
        metadata = resolveImageDownloadMetadata(
          fileName: image.fileName,
          imageUrl: image.imageUrl,
          contentType: response.headers['content-type'] ?? image.mimeType,
          bytes: bodyBytes,
        );
        onProgress?.call(
          ImageDownloadProgress(
            phase: ImageDownloadPhase.finalizing,
            message: '正在整理图片...',
            downloadedBytes: bodyBytes.length,
            totalBytes: totalBytes ?? bodyBytes.length,
          ),
        );
        href = html.Url.createObjectUrlFromBlob(
          html.Blob([bodyBytes], metadata.mimeType),
        );
        shouldRevokeObjectUrl = true;
        onProgress?.call(
          ImageDownloadProgress(
            phase: ImageDownloadPhase.completed,
            message: '图片已准备好',
            downloadedBytes: bodyBytes.length,
            totalBytes: totalBytes ?? bodyBytes.length,
          ),
        );
      } finally {
        client.close();
      }
    }

    if (href.isEmpty) {
      _showSnackBar(messenger, '当前图片没有可下载的数据。');
      return;
    }

    final anchor = html.AnchorElement(href: href)
      ..download = metadata.fileName
      ..target = '_blank'
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    if (shouldRevokeObjectUrl) {
      html.Url.revokeObjectUrl(href);
    }

    _showSnackBar(messenger, '下载已开始：${metadata.fileName}');
  } catch (e) {
    final fallbackUrl = image.imageUrl;
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      try {
        js.context.callMethod('open', [fallbackUrl, '_blank']);
        _showSnackBar(messenger, '已在新标签页中打开图片。');
        return;
      } catch (_) {
        // ignore and fall through to final message
      }
    }

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
