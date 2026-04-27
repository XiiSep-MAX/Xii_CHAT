import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

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
      final response = await http
          .get(Uri.parse(_versionCheckUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VersionInfo.fromJson(data);
      }
    } catch (e) {
      stderr.writeln('版本检查失败: $e');
    }
    return null;
  }

  /// 启动 MSIX / App Installer 更新流程
  static Future<UpdateInstallResult> downloadAndInstallUpdate(
    VersionInfo versionInfo,
  ) async {
    try {
      if (!Platform.isWindows) {
        return const UpdateInstallResult.failure('MSIX 更新仅支持 Windows 桌面版。');
      }

      final downloadUrl = versionInfo.downloadUrl.trim();
      if (downloadUrl.isEmpty) {
        return const UpdateInstallResult.failure('未配置更新下载地址。');
      }

      final packageType = _detectPackageType(downloadUrl);
      if (packageType == _UpdatePackageType.unsupported) {
        return const UpdateInstallResult.failure(
          '更新地址必须是 .appinstaller、.msix、.msixbundle、.appx 或 .appxbundle 文件。',
        );
      }

      final uri = Uri.tryParse(downloadUrl);
      if (uri == null) {
        return UpdateInstallResult.failure('更新地址格式无效: $downloadUrl');
      }

      if (packageType == _UpdatePackageType.appInstaller) {
        final launched = await _launchMsixInstallerUri(uri);
        if (!launched) {
          return const UpdateInstallResult.failure(
              '无法启动 Windows App Installer。');
        }

        return const UpdateInstallResult.success(
          'Windows App Installer 已启动，请按系统提示完成升级。'
          '\n\n如果安装时提示关闭当前应用，请确认关闭，安装完成后重新打开即可。',
        );
      }

      final localPackage = await _downloadMsixPackage(
        uri: uri,
        version: versionInfo.version,
      );
      final launched = await _openLocalInstaller(localPackage.path);
      if (!launched) {
        return UpdateInstallResult.failure(
          '安装包已下载到 ${localPackage.path}，但无法自动打开，请手动双击安装。',
        );
      }

      return const UpdateInstallResult.success(
        'MSIX 安装包已打开，请按系统提示完成升级。'
        '\n\n安装期间如果提示关闭当前应用，请确认关闭。',
      );
    } catch (e) {
      stderr.writeln('更新启动失败: $e');
      return UpdateInstallResult.failure('启动更新失败: $e');
    }
  }

  static Future<bool> openDownloadUrl(String url) async {
    if (!Platform.isWindows) return false;

    final target = url.trim();
    if (target.isEmpty) return false;

    try {
      final uri = Uri.tryParse(target);
      if (uri != null &&
          _detectPackageTypeFromUri(uri) == _UpdatePackageType.appInstaller) {
        return _launchMsixInstallerUri(uri);
      }

      await Process.start('explorer.exe', [target]);
      return true;
    } catch (e) {
      stderr.writeln('打开更新链接失败: $e');
      return false;
    }
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
      stderr.writeln('版本比较错误: $e');
      return false;
    }
  }

  /// 比较两个版本列表 (返回 1 表示 v1 > v2, -1 表示 v1 < v2, 0 表示相等)
  static int _compareVersions(List<int> v1, List<int> v2) {
    final maxLength = v1.length > v2.length ? v1.length : v2.length;

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

  static _UpdatePackageType _detectPackageType(String downloadUrl) {
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) {
      return _UpdatePackageType.unsupported;
    }

    return _detectPackageTypeFromUri(uri);
  }

  static _UpdatePackageType _detectPackageTypeFromUri(Uri uri) {
    final lowerPath = uri.path.toLowerCase();
    if (lowerPath.endsWith('.appinstaller')) {
      return _UpdatePackageType.appInstaller;
    }

    const msixExtensions = [
      '.msix',
      '.msixbundle',
      '.appx',
      '.appxbundle',
    ];
    if (msixExtensions.any(lowerPath.endsWith)) {
      return _UpdatePackageType.msixPackage;
    }

    return _UpdatePackageType.unsupported;
  }

  static Future<File> _downloadMsixPackage({
    required Uri uri,
    required String version,
  }) async {
    stderr.writeln('开始下载 MSIX 安装包: $uri');
    final response = await http.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('下载失败: HTTP ${response.statusCode}');
    }

    final tempDir =
        await Directory.systemTemp.createTemp('xii_raw_graph_update_');
    final filename = _resolvePackageFilename(uri, version);
    final file = File(path.join(tempDir.path, filename));
    await file.writeAsBytes(response.bodyBytes, flush: true);
    stderr.writeln('MSIX 安装包下载完成: ${file.path}');
    return file;
  }

  static String _resolvePackageFilename(Uri uri, String version) {
    final lastSegment =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (lastSegment.isNotEmpty) {
      return lastSegment;
    }

    return 'Xii_Raw_Graph_Update_v$version.msix';
  }

  static Future<bool> _launchMsixInstallerUri(Uri uri) async {
    final installerUri = 'ms-appinstaller:?source=${uri.toString()}';

    try {
      await Process.start('explorer.exe', [installerUri]);
      return true;
    } catch (e) {
      stderr.writeln('启动 App Installer 失败: $e');
      return false;
    }
  }

  static Future<bool> _openLocalInstaller(String filePath) async {
    try {
      await Process.start('explorer.exe', [filePath]);
      return true;
    } catch (e) {
      stderr.writeln('打开本地安装包失败: $e');
      return false;
    }
  }
}

enum _UpdatePackageType {
  appInstaller,
  msixPackage,
  unsupported,
}

class UpdateInstallResult {
  final bool success;
  final String message;

  const UpdateInstallResult.success(this.message) : success = true;

  const UpdateInstallResult.failure(this.message) : success = false;
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
