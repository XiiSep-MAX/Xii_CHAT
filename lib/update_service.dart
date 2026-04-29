import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 版本更新服务 - 检查并管理应用版本更新
class UpdateService {
  // 版本检查元数据地址
  static const String _versionCheckUrl =
      'https://raw.githubusercontent.com/XiiSep-MAX/Xii_CHAT/main/version.json';
  static const String _bundledUpdaterFileName = 'xii_updater.exe';
  static const List<String> _preservedInstallFiles = ['.env'];
  static const Duration _packageConnectTimeout = Duration(seconds: 20);
  static const Duration _packageReadTimeout = Duration(seconds: 20);
  static const Duration _packageAttemptTimeout = Duration(minutes: 8);
  static const int _maxDownloadAttempts = 3;

  static String get _powerShellExecutable => path.join(
        Platform.environment['SystemRoot'] ?? r'C:\Windows',
        'System32',
        'WindowsPowerShell',
        'v1.0',
        'powershell.exe',
      );

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

  /// 下载并提示安装便携版更新
  static Future<UpdateInstallResult> downloadAndInstallUpdate(
    VersionInfo versionInfo, {
    void Function(UpdateDownloadProgress progress)? onProgress,
  }) async {
    try {
      if (!Platform.isWindows) {
        return const UpdateInstallResult.failure('便携版更新仅支持 Windows 桌面版。');
      }

      final downloadUrl = versionInfo.downloadUrl.trim();
      if (downloadUrl.isEmpty) {
        return const UpdateInstallResult.failure('未配置更新下载地址。');
      }

      final uri = Uri.tryParse(downloadUrl);
      if (uri == null) {
        return UpdateInstallResult.failure('更新地址格式无效: $downloadUrl');
      }

      final packageType = _detectPackageTypeFromUri(uri);

      if (packageType == _UpdatePackageType.zipPackage ||
          packageType == _UpdatePackageType.executable) {
        try {
          final localPackage = await _downloadPortablePackage(
            uri: uri,
            version: versionInfo.version,
            packageType: packageType,
            onProgress: onProgress,
          );
          if (packageType == _UpdatePackageType.zipPackage) {
            try {
              onProgress?.call(
                UpdateDownloadProgress(
                  phase: UpdateDownloadPhase.preparingInstall,
                  message: '下载完成，正在准备自动安装...',
                  downloadedBytes: await localPackage.length(),
                  totalBytes: await localPackage.length(),
                  attempt: 1,
                  maxAttempts: _maxDownloadAttempts,
                ),
              );

              await _launchAutomaticZipUpdate(localPackage: localPackage);
              return const UpdateInstallResult.autoRestart(
                '更新包已下载完成，应用将自动关闭并安装新版本。',
              );
            } catch (error) {
              stderr.writeln('自动安装启动失败: $error');
              final opened = await _openFolderAndSelectFile(localPackage.path);
              final suffix = opened ? '，并已为你打开所在目录。' : '。';
              return UpdateInstallResult.success(
                '更新包已下载到：${localPackage.path}$suffix\n\n'
                '自动安装未能启动，请先关闭当前版本，再手动解压覆盖。',
              );
            }
          }

          final opened = await _openFolderAndSelectFile(localPackage.path);
          final suffix = opened ? '，并已为你打开所在目录。' : '。';
          return UpdateInstallResult.success(
            '更新包已下载到：${localPackage.path}$suffix\n\n'
            '请关闭旧版本后运行新文件。',
          );
        } on TimeoutException catch (error) {
          stderr.writeln('自动下载超时: $error');
          return _fallbackToBrowserDownload(
            downloadUrl: downloadUrl,
            onProgress: onProgress,
            reason: '自动下载超时',
          );
        } on SocketException catch (error) {
          stderr.writeln('自动下载网络异常: $error');
          return _fallbackToBrowserDownload(
            downloadUrl: downloadUrl,
            onProgress: onProgress,
            reason: '网络连接不稳定',
          );
        } on HttpException catch (error) {
          stderr.writeln('自动下载 HTTP 异常: $error');
          return _fallbackToBrowserDownload(
            downloadUrl: downloadUrl,
            onProgress: onProgress,
            reason: '下载源暂时不可用',
          );
        }
      }

      final opened = await openDownloadUrl(downloadUrl);
      if (opened) {
        return const UpdateInstallResult.success(
          '已为你打开更新下载页，请按页面提示获取最新版本。',
        );
      }

      return const UpdateInstallResult.failure(
        '无法识别更新包类型，请手动打开下载链接。',
      );
    } catch (e) {
      stderr.writeln('更新启动失败: $e');
      return UpdateInstallResult.failure('启动更新失败: $e');
    }
  }

  static Future<UpdateInstallResult> _fallbackToBrowserDownload({
    required String downloadUrl,
    required String reason,
    void Function(UpdateDownloadProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      UpdateDownloadProgress(
        phase: UpdateDownloadPhase.fallback,
        message: '$reason，正在为你打开浏览器下载链接...',
        downloadedBytes: 0,
        totalBytes: null,
        attempt: _maxDownloadAttempts,
        maxAttempts: _maxDownloadAttempts,
      ),
    );

    final opened = await openDownloadUrl(downloadUrl);
    if (opened) {
      return UpdateInstallResult.success(
        '$reason，已为你打开浏览器下载链接，请直接在浏览器中完成下载。',
      );
    }

    return UpdateInstallResult.failure('$reason，请手动访问更新链接：$downloadUrl');
  }

  static Future<bool> openDownloadUrl(String url) async {
    if (!Platform.isWindows) return false;

    final target = url.trim();
    if (target.isEmpty) return false;

    try {
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

  static _UpdatePackageType _detectPackageTypeFromUri(Uri uri) {
    final lowerPath = uri.path.toLowerCase();
    if (lowerPath.endsWith('.zip')) {
      return _UpdatePackageType.zipPackage;
    }

    if (lowerPath.endsWith('.exe')) {
      return _UpdatePackageType.executable;
    }

    return _UpdatePackageType.genericUrl;
  }

  static Future<File> _downloadPortablePackage({
    required Uri uri,
    required String version,
    required _UpdatePackageType packageType,
    void Function(UpdateDownloadProgress progress)? onProgress,
  }) async {
    stderr.writeln('开始下载便携版更新包: $uri');
    final downloadDir = await _resolveDownloadsDirectory();
    if (downloadDir == null) {
      throw Exception('无法定位下载目录');
    }

    final defaultExtension =
        packageType == _UpdatePackageType.zipPackage ? '.zip' : '.exe';
    final filename = _resolvePackageFilename(
      uri,
      version,
      defaultExtension: defaultExtension,
    );
    final file = await _resolveAvailableFile(downloadDir, filename);
    final tempFile = File('${file.path}.part');

    await _deleteIfExists(tempFile);

    final client = http.Client();
    Object? lastError;
    StackTrace? lastStackTrace;

    try {
      for (var attempt = 1; attempt <= _maxDownloadAttempts; attempt++) {
        try {
          if (attempt > 1) {
            onProgress?.call(
              UpdateDownloadProgress(
                phase: UpdateDownloadPhase.retrying,
                message: '下载中断，正在进行第 $attempt/$_maxDownloadAttempts 次重试...',
                downloadedBytes: 0,
                totalBytes: null,
                attempt: attempt,
                maxAttempts: _maxDownloadAttempts,
              ),
            );
          }

          final downloadedFile = await _downloadPortablePackageAttempt(
            client: client,
            uri: uri,
            targetFile: file,
            tempFile: tempFile,
            attempt: attempt,
            onProgress: onProgress,
          ).timeout(_packageAttemptTimeout);

          stderr.writeln('便携版更新包下载完成: ${downloadedFile.path}');
          return downloadedFile;
        } catch (error, stackTrace) {
          lastError = error;
          lastStackTrace = stackTrace;
          await _deleteIfExists(tempFile);

          if (!_shouldRetry(error) || attempt >= _maxDownloadAttempts) {
            break;
          }
        }
      }
    } finally {
      client.close();
    }

    Error.throwWithStackTrace(
      lastError ?? Exception('下载失败：未知错误'),
      lastStackTrace ?? StackTrace.current,
    );
  }

  static Future<File> _downloadPortablePackageAttempt({
    required http.Client client,
    required Uri uri,
    required File targetFile,
    required File tempFile,
    required int attempt,
    void Function(UpdateDownloadProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      UpdateDownloadProgress(
        phase: UpdateDownloadPhase.connecting,
        message: '正在连接下载服务器...',
        downloadedBytes: 0,
        totalBytes: null,
        attempt: attempt,
        maxAttempts: _maxDownloadAttempts,
      ),
    );

    final request = http.Request('GET', uri);
    final response = await client.send(request).timeout(_packageConnectTimeout);

    if (response.statusCode != 200) {
      throw HttpException('下载失败: HTTP ${response.statusCode}');
    }

    final totalBytes =
        response.contentLength != null && response.contentLength! > 0
            ? response.contentLength
            : null;

    IOSink? sink;
    var downloadedBytes = 0;

    try {
      sink = tempFile.openWrite();
      onProgress?.call(
        UpdateDownloadProgress(
          phase: UpdateDownloadPhase.downloading,
          message: '正在下载更新包...',
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          attempt: attempt,
          maxAttempts: _maxDownloadAttempts,
        ),
      );

      await for (final chunk in response.stream.timeout(_packageReadTimeout)) {
        downloadedBytes += chunk.length;
        sink.add(chunk);
        onProgress?.call(
          UpdateDownloadProgress(
            phase: UpdateDownloadPhase.downloading,
            message: '正在下载更新包...',
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            attempt: attempt,
            maxAttempts: _maxDownloadAttempts,
          ),
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (downloadedBytes <= 0) {
        throw const HttpException('下载结果为空，请稍后重试。');
      }

      onProgress?.call(
        UpdateDownloadProgress(
          phase: UpdateDownloadPhase.finalizing,
          message: '下载完成，正在整理更新包...',
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes ?? downloadedBytes,
          attempt: attempt,
          maxAttempts: _maxDownloadAttempts,
        ),
      );

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
      return targetFile;
    } catch (_) {
      await sink?.close();
      rethrow;
    }
  }

  static bool _shouldRetry(Object error) {
    return error is TimeoutException ||
        error is SocketException ||
        error is HttpException;
  }

  static Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String _resolvePackageFilename(
    Uri uri,
    String version, {
    String defaultExtension = '.zip',
  }) {
    final lastSegment =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (lastSegment.isNotEmpty) {
      return lastSegment;
    }

    return 'Xii_Raw_Graph_Update_v$version$defaultExtension';
  }

  static Future<bool> _openFolderAndSelectFile(String filePath) async {
    try {
      await Process.start('explorer.exe', ['/select,', filePath]);
      return true;
    } catch (e) {
      stderr.writeln('打开下载目录失败: $e');
      return false;
    }
  }

  static Future<Directory?> _resolveDownloadsDirectory() async {
    final downloadDir = await getDownloadsDirectory();
    if (downloadDir != null) {
      await downloadDir.create(recursive: true);
      return downloadDir;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null || userProfile.isEmpty) {
      return null;
    }

    final fallbackDir = Directory(path.join(userProfile, 'Downloads'));
    await fallbackDir.create(recursive: true);
    return fallbackDir;
  }

  static Future<File> _resolveAvailableFile(
    Directory directory,
    String fileName,
  ) async {
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

  static Future<void> _launchAutomaticZipUpdate({
    required File localPackage,
  }) async {
    final appExecutable = File(Platform.resolvedExecutable);
    final appDir = appExecutable.parent.path;
    final targetExe = path.basename(appExecutable.path);
    final updaterArguments = [
      '--app-dir=$appDir',
      '--zip-path=${localPackage.path}',
      '--target-exe=$targetExe',
      '--source-pid=$pid',
      '--preserve=${_preservedInstallFiles.join(';')}',
    ];

    final bundledUpdater = File(path.join(appDir, _bundledUpdaterFileName));
    if (await bundledUpdater.exists()) {
      final tempUpdater = await _copyUpdaterToTemp(bundledUpdater);
      await _startDetachedProcessHidden(
        tempUpdater.path,
        updaterArguments,
      );
      return;
    }

    final fallbackScript = await _createFallbackUpdaterScript();
    await Process.start(
      _powerShellExecutable,
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        fallbackScript.path,
        '-AppDir',
        appDir,
        '-ZipPath',
        localPackage.path,
        '-TargetExe',
        targetExe,
        '-SourcePid',
        '$pid',
        '-Preserve',
        _preservedInstallFiles.join(';'),
      ],
      mode: ProcessStartMode.detached,
    );
  }

  static Future<File> _copyUpdaterToTemp(File bundledUpdater) async {
    final tempDir = await Directory.systemTemp.createTemp('xii_updater_');
    final copiedUpdater =
        File(path.join(tempDir.path, _bundledUpdaterFileName));
    await bundledUpdater.copy(copiedUpdater.path);
    return copiedUpdater;
  }

  static Future<File> _createFallbackUpdaterScript() async {
    final tempDir = await Directory.systemTemp.createTemp('xii_update_script_');
    final scriptFile = File(path.join(tempDir.path, 'apply_update.ps1'));
    await scriptFile.writeAsString(_fallbackUpdaterScript);
    return scriptFile;
  }

  static Future<void> _startDetachedProcessHidden(
    String filePath,
    List<String> arguments,
  ) async {
    final argumentList = arguments.map(_toPowerShellQuotedString).join(', ');
    final command = StringBuffer()
      ..write('Start-Process -FilePath ')
      ..write(_toPowerShellQuotedString(filePath));
    if (arguments.isNotEmpty) {
      command
        ..write(' -ArgumentList @(')
        ..write(argumentList)
        ..write(')');
    }
    command.write(' -WindowStyle Hidden');

    await Process.start(
      _powerShellExecutable,
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-Command',
        command.toString(),
      ],
      mode: ProcessStartMode.detached,
    );
  }

  static String _toPowerShellQuotedString(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }

  static String get _fallbackUpdaterScript => r'''
param(
  [Parameter(Mandatory = $true)][string]$AppDir,
  [Parameter(Mandatory = $true)][string]$ZipPath,
  [Parameter(Mandatory = $true)][string]$TargetExe,
  [Parameter(Mandatory = $true)][int]$SourcePid,
  [string]$Preserve = '.env'
)

$ErrorActionPreference = 'Stop'

function Show-ErrorDialog([string]$Message) {
  try {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
      $Message,
      'Xii_Raw Graph 自动更新失败',
      [System.Windows.MessageBoxButton]::OK,
      [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
  } catch {
  }
}

function Get-SourceRoot([string]$ExtractDir) {
  $entries = Get-ChildItem -LiteralPath $ExtractDir -Force
  if ($entries.Count -eq 1 -and $entries[0].PSIsContainer) {
    return $entries[0].FullName
  }
  return $ExtractDir
}

try {
  $workDir = Join-Path $env:TEMP ('Xii_Raw_Graph_Update_' + [Guid]::NewGuid().ToString('N'))
  $extractDir = Join-Path $workDir 'extract'
  New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

  if ($SourcePid -gt 0) {
    Wait-Process -Id $SourcePid -Timeout 120 -ErrorAction SilentlyContinue
  }

  Expand-Archive -LiteralPath $ZipPath -DestinationPath $extractDir -Force
  $sourceRoot = Get-SourceRoot $extractDir

  $robocopyArgs = @(
    $sourceRoot,
    $AppDir,
    '/MIR',
    '/R:2',
    '/W:1',
    '/NFL',
    '/NDL',
    '/NJH',
    '/NJS',
    '/NP'
  )

  if ($Preserve) {
    $preservedFiles = $Preserve.Split(';') | Where-Object { $_ }
    if ($preservedFiles.Count -gt 0) {
      $robocopyArgs += '/XF'
      $robocopyArgs += $preservedFiles
    }
  }

  & robocopy @robocopyArgs | Out-Null
  if ($LASTEXITCODE -gt 7) {
    throw "覆盖安装目录失败，Robocopy 退出码: $LASTEXITCODE"
  }

  $targetPath = Join-Path $AppDir $TargetExe
  if (-not (Test-Path -LiteralPath $targetPath)) {
    throw "未找到更新后的启动文件: $targetPath"
  }

  Start-Process -FilePath $targetPath -WorkingDirectory $AppDir
  Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
} catch {
  Show-ErrorDialog("自动更新失败：$($_.Exception.Message)`n`n更新包保留在：$ZipPath")
  try {
    $targetPath = Join-Path $AppDir $TargetExe
    if (Test-Path -LiteralPath $targetPath) {
      Start-Process -FilePath $targetPath -WorkingDirectory $AppDir
    }
  } catch {
  }
}
''';
}

enum _UpdatePackageType {
  zipPackage,
  executable,
  genericUrl,
}

enum UpdateDownloadPhase {
  connecting,
  downloading,
  retrying,
  finalizing,
  preparingInstall,
  restarting,
  fallback,
}

class UpdateDownloadProgress {
  final UpdateDownloadPhase phase;
  final String message;
  final int downloadedBytes;
  final int? totalBytes;
  final int attempt;
  final int maxAttempts;

  const UpdateDownloadProgress({
    required this.phase,
    required this.message,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.attempt,
    required this.maxAttempts,
  });

  bool get hasKnownTotal => totalBytes != null && totalBytes! > 0;

  double? get progress {
    if (!hasKnownTotal) return null;
    return (downloadedBytes / totalBytes!).clamp(0.0, 1.0);
  }

  String get progressLabel {
    if (!hasKnownTotal) return '已下载 ${_formatBytes(downloadedBytes)}';
    final percent = ((progress ?? 0) * 100).toStringAsFixed(0);
    return '$percent% · ${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes!)}';
  }

  static String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final fractionDigits = value >= 100 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
  }
}

class UpdateInstallResult {
  final bool success;
  final String message;
  final bool shouldExitApplication;

  const UpdateInstallResult.success(
    this.message, {
    this.shouldExitApplication = false,
  }) : success = true;

  const UpdateInstallResult.autoRestart(this.message)
      : success = true,
        shouldExitApplication = true;

  const UpdateInstallResult.failure(this.message)
      : success = false,
        shouldExitApplication = false;
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
