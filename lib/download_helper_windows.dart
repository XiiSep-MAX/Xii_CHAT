import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

void downloadImagePlatform(String url) async {
  print('🔗 开始下载图片 (Windows): $url');

  try {
    // 获取下载目录
    final downloadDir = await getDownloadsDirectory();
    if (downloadDir == null) {
      print('❌ 无法获取下载目录');
      return;
    }

    // 提取文件名
    final filename = _extractFilename(url);
    final filePath = path.join(downloadDir.path, filename);

    print('📁 保存路径: $filePath');

    // 下载文件
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      print('❌ 下载失败: HTTP ${response.statusCode}');
      return;
    }

    // 保存到文件
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    print('✅ 图片已保存到: $filePath');

    // 可选：打开文件所在目录
    // await Process.run('explorer.exe', ['/select,', filePath]);

  } catch (e) {
    print('❌ 下载过程中出错: $e');
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