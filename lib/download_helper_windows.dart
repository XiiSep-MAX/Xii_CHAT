import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<void> downloadImagePlatform(String url, {BuildContext? context}) async {
  final messenger = context == null ? null : ScaffoldMessenger.maybeOf(context);
  _showSnackBar(messenger, '开始下载图片...');

  try {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnackBar(messenger, '图片地址无效，无法下载。');
      return;
    }

    final downloadDir = await _resolveDownloadsDirectory();
    if (downloadDir == null) {
      _showSnackBar(messenger, '无法定位下载目录，请检查系统配置。');
      return;
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      _showSnackBar(messenger, '下载失败：HTTP ${response.statusCode}');
      return;
    }

    final filename = _buildFilename(
      uri: uri,
      contentType: response.headers['content-type'],
    );
    final file = await _resolveAvailableFile(downloadDir, filename);
    await file.writeAsBytes(response.bodyBytes, flush: true);

    _showSnackBar(messenger, '图片已保存：${path.basename(file.path)}');
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

String _buildFilename({
  required Uri uri,
  String? contentType,
}) {
  final extracted = _extractFilename(uri);
  if (path.extension(extracted).isNotEmpty) {
    return extracted;
  }

  return '$extracted${_extensionFromContentType(contentType)}';
}

String _extractFilename(Uri uri) {
  try {
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last;
      if (lastSegment.trim().isNotEmpty) {
        return lastSegment;
      }
    }
    return 'ai_generated_image.png';
  } catch (e) {
    return 'ai_generated_image.png';
  }
}

String _extensionFromContentType(String? contentType) {
  final lowerType = contentType?.toLowerCase() ?? '';
  if (lowerType.contains('jpeg') || lowerType.contains('jpg')) {
    return '.jpg';
  }
  if (lowerType.contains('gif')) {
    return '.gif';
  }
  if (lowerType.contains('webp')) {
    return '.webp';
  }
  if (lowerType.contains('bmp')) {
    return '.bmp';
  }
  return '.png';
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
