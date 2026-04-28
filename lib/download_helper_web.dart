import 'dart:html' as html;
import 'dart:js' as js;

import 'package:flutter/material.dart';

import 'models.dart';

Future<void> downloadImagePlatform(
  GeneratedImageAsset image, {
  BuildContext? context,
}) async {
  final messenger = context == null ? null : ScaffoldMessenger.maybeOf(context);
  _showSnackBar(messenger, '开始下载图片...');

  try {
    final filename = image.fileName;
    final href = image.hasBytes
        ? html.Url.createObjectUrlFromBlob(
            html.Blob([image.bytes], image.mimeType),
          )
        : image.imageUrl;

    if (href == null || href.isEmpty) {
      _showSnackBar(messenger, '当前图片没有可下载的数据。');
      return;
    }

    final anchor = html.AnchorElement(href: href)
      ..download = filename
      ..target = '_blank'
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    if (image.hasBytes) {
      html.Url.revokeObjectUrl(href);
    }

    _showSnackBar(messenger, '下载已开始：$filename');
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
