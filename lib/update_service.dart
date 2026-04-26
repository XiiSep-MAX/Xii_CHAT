import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 版本更新服务 - 检查并管理应用版本更新
class UpdateService {
  // 版本检查服务器 URL（你需要替换为自己的服务器）
  static const String _versionCheckUrl =
      'https://raw.githubusercontent.com/your-repo/version.json';

  /// 获取远程版本信息
  static Future<VersionInfo?> checkForUpdates({
    required String currentVersion,
  }) async {
    try {
      final response = await http.get(Uri.parse(_versionCheckUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VersionInfo.fromJson(data);
      }
    } catch (e) {
      print('版本检查失败: $e');
    }
    return null;
  }

  /// 下载并安装更新
  static Future<bool> downloadAndInstallUpdate(VersionInfo versionInfo) async {
    try {
      // 获取下载目录
      final downloadDir = await getDownloadsDirectory();
      if (downloadDir == null) return false;

      // 生成文件名
      final fileName = 'Xii_Raw_Graph_Update_v${versionInfo.version}.zip';
      final filePath = path.join(downloadDir.path, fileName);

      // 下载文件
      print('开始下载更新: ${versionInfo.downloadUrl}');
      final response = await http.get(Uri.parse(versionInfo.downloadUrl));

      if (response.statusCode != 200) {
        print('下载失败: ${response.statusCode}');
        return false;
      }

      // 保存文件
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      print('下载完成: $filePath');

      // 显示安装提示
      _showInstallationInstructions(filePath, versionInfo);

      return true;
    } catch (e) {
      print('更新下载失败: $e');
      return false;
    }
  }

  /// 显示安装说明
  static void _showInstallationInstructions(String filePath, VersionInfo versionInfo) {
    print('''
╔══════════════════════════════════════════════════════════════╗
║                     🎉 更新下载完成！                          ║
╠══════════════════════════════════════════════════════════════╣
║ 文件位置: $filePath
║ 版本: ${versionInfo.version}
║
║ 安装步骤:
║ 1. 关闭当前运行的应用
║ 2. 解压下载的 ZIP 文件
║ 3. 将新文件覆盖到应用目录
║ 4. 重新启动应用
║
║ 更新内容:
║ ${versionInfo.releaseNotes.replaceAll('\n', '\n║ ')}
╚══════════════════════════════════════════════════════════════╝
    ''');
  }

  /// 比较版本号 (返回 true 表示需要更新)
  static bool isUpdateAvailable(
    String currentVersion,
    String remoteVersion,
  ) {
    try {
      final current = _parseVersion(currentVersion);
      final remote = _parseVersion(remoteVersion);
      return _compareVersions(remote, current) > 0;
    } catch (e) {
      print('版本比较错误: $e');
      return false;
    }
  }

  /// 比较两个版本列表 (返回 1 表示 v1 > v2, -1 表示 v1 < v2, 0 表示相等)
  static int _compareVersions(List<int> v1, List<int> v2) {
    final maxLength = v1.length > v2.length ? v2.length : v1.length;

    for (int i = 0; i < maxLength; i++) {
      final a = i < v1.length ? v1[i] : 0;
      final b = i < v2.length ? v2[i] : 0;

      if (a > b) return 1;
      if (a < b) return -1;
    }

    return 0;
  }

  /// 解析版本字符串为可比较的元组
  static List<int> _parseVersion(String version) {
    return version
        .split('.')
        .map((e) => int.parse(e.replaceAll(RegExp(r'[^\d]'), '')))
        .toList();
  }
}

/// 版本信息数据模型
class VersionInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final bool isForced; // 是否强制更新

  VersionInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isForced = false,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version'] ?? '1.0.0',
      downloadUrl: json['downloadUrl'] ?? '',
      releaseNotes: json['releaseNotes'] ?? 'New version available',
      isForced: json['isForced'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'downloadUrl': downloadUrl,
        'releaseNotes': releaseNotes,
        'isForced': isForced,
      };
}
