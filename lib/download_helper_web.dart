import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';

Future<void> downloadImagePlatform(String url, {BuildContext? context}) async {
  print('🔗 开始下载图片: $url');

  // 显示下载开始提示
  if (context != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('开始下载图片...')),
    );
  }

  try {
    // Try using the download attribute first
    final filename = _extractFilename(url);
    print('📁 提取的文件名: $filename');

    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..target = '_blank'
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    print('✅ 下载已触发');

    // 显示成功提示
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载已开始: $filename')),
      );
    }

  } catch (e) {
    print('❌ 下载失败，使用备用方案: $e');

    // 显示错误提示
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败: ${e.toString()}')),
      );
    }

    // Fallback: open in new tab
    try {
      js.context.callMethod('open', [url, '_blank']);
      print('✅ 在新标签页中打开');

      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已在新标签页中打开图片')),
        );
      }
    } catch (fallbackError) {
      print('❌ 备用方案也失败: $fallbackError');

      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法下载图片')),
        );
      }
    }
  }
}

String _extractFilename(String url) {
  try {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last;
      if (lastSegment.contains('.')) {
        return lastSegment;
      }
    }
    return 'ai_generated_image.png';
  } catch (e) {
    return 'ai_generated_image.png';
  }
}
