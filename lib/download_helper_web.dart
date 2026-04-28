import 'dart:html' as html;
import 'dart:js' as js;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'image_download_metadata.dart';
import 'models.dart';

Future<void> downloadImagePlatform(
  GeneratedImageAsset image, {
  BuildContext? context,
}) async {
  final messenger = context == null ? null : ScaffoldMessenger.maybeOf(context);
  _showSnackBar(messenger, '开始下载图片...');

  try {
    late final ResolvedImageDownloadMetadata metadata;
    late final String href;
    var shouldRevokeObjectUrl = false;

    if (image.hasBytes) {
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
    } else {
      final uri = Uri.tryParse(image.imageUrl ?? '');
      if (uri == null) {
        _showSnackBar(messenger, '图片地址无效，无法下载。');
        return;
      }

      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        _showSnackBar(messenger, '下载失败：HTTP ${response.statusCode}');
        return;
      }

      metadata = resolveImageDownloadMetadata(
        fileName: image.fileName,
        imageUrl: image.imageUrl,
        contentType: response.headers['content-type'] ?? image.mimeType,
        bytes: response.bodyBytes,
      );
      href = html.Url.createObjectUrlFromBlob(
        html.Blob([response.bodyBytes], metadata.mimeType),
      );
      shouldRevokeObjectUrl = true;
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
