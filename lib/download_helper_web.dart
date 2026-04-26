import 'dart:html' as html;
import 'dart:js' as js;

void downloadImagePlatform(String url) {
  print('🔗 开始下载图片: $url');

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
  } catch (e) {
    print('❌ 下载失败，使用备用方案: $e');
    // Fallback: open in new tab
    try {
      js.context.callMethod('open', [url, '_blank']);
      print('✅ 在新标签页中打开');
    } catch (fallbackError) {
      print('❌ 备用方案也失败: $fallbackError');
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
