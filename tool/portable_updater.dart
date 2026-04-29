import 'dart:io';

import 'package:path/path.dart' as path;

String get _powerShellExecutable => path.join(
      Platform.environment['SystemRoot'] ?? r'C:\Windows',
      'System32',
      'WindowsPowerShell',
      'v1.0',
      'powershell.exe',
    );

String get _robocopyExecutable => path.join(
    Platform.environment['SystemRoot'] ?? r'C:\Windows',
    'System32',
    'robocopy.exe');

String get _cmdExecutable => path.join(
    Platform.environment['SystemRoot'] ?? r'C:\Windows', 'System32', 'cmd.exe');

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final appDir = options['app-dir'];
  final zipPath = options['zip-path'];
  final targetExe = options['target-exe'];
  final sourcePid = int.tryParse(options['source-pid'] ?? '') ?? 0;
  final preserve = (options['preserve'] ?? '.env')
      .split(';')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();

  if (appDir == null || zipPath == null || targetExe == null) {
    stderr.writeln('缺少自动更新参数。');
    exitCode = 1;
    return;
  }

  final updaterExecutable = File(Platform.resolvedExecutable);
  final updaterDir = updaterExecutable.parent;
  final workDir = await Directory.systemTemp.createTemp('xii_update_work_');
  final extractDir = Directory(path.join(workDir.path, 'extract'));
  await extractDir.create(recursive: true);

  try {
    if (sourcePid > 0) {
      await _waitForProcessExit(sourcePid);
    }

    await _extractZip(zipPath, extractDir.path);
    final sourceRoot = await _resolveExtractedSourceRoot(extractDir);
    await _mirrorInstallation(
      sourceDir: sourceRoot.path,
      targetDir: appDir,
      preserveFiles: preserve,
    );

    final targetPath = path.join(appDir, targetExe);
    if (!await File(targetPath).exists()) {
      throw Exception('未找到更新后的启动文件：$targetPath');
    }

    await Process.start(
      targetPath,
      const [],
      workingDirectory: appDir,
      mode: ProcessStartMode.detached,
    );

    _scheduleCleanup(
      workDir: workDir.path,
      updaterDir: updaterDir.path,
      appDir: appDir,
    );
  } catch (error) {
    await _showErrorDialog('自动更新失败：$error\n\n更新包保留在：$zipPath');
    final targetPath = path.join(appDir, targetExe);
    if (await File(targetPath).exists()) {
      await Process.start(
        targetPath,
        const [],
        workingDirectory: appDir,
        mode: ProcessStartMode.detached,
      );
    }
    exitCode = 1;
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final options = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--')) continue;
    final separatorIndex = arg.indexOf('=');
    if (separatorIndex <= 2) continue;
    final key = arg.substring(2, separatorIndex);
    final value = arg.substring(separatorIndex + 1);
    options[key] = value;
  }
  return options;
}

Future<void> _waitForProcessExit(int sourcePid) async {
  await Process.run(_powerShellExecutable, [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-Command',
    'Wait-Process -Id $sourcePid -Timeout 120 -ErrorAction SilentlyContinue',
  ]);
}

Future<void> _extractZip(String zipPath, String extractDir) async {
  final result = await Process.run(_powerShellExecutable, [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-Command',
    'Expand-Archive -LiteralPath ${_psQuote(zipPath)} '
        '-DestinationPath ${_psQuote(extractDir)} -Force',
  ]);

  if (result.exitCode != 0) {
    throw Exception(
      '解压更新包失败：${result.stderr.toString().trim().isEmpty ? result.stdout : result.stderr}',
    );
  }
}

Future<Directory> _resolveExtractedSourceRoot(Directory extractDir) async {
  final entries = extractDir.listSync();
  if (entries.length == 1 && entries.first is Directory) {
    return entries.first as Directory;
  }
  return extractDir;
}

Future<void> _mirrorInstallation({
  required String sourceDir,
  required String targetDir,
  required List<String> preserveFiles,
}) async {
  final arguments = <String>[
    sourceDir,
    targetDir,
    '/MIR',
    '/R:2',
    '/W:1',
    '/NFL',
    '/NDL',
    '/NJH',
    '/NJS',
    '/NP',
  ];

  if (preserveFiles.isNotEmpty) {
    arguments.add('/XF');
    arguments.addAll(preserveFiles);
  }

  final result = await Process.run(_robocopyExecutable, arguments);
  if (result.exitCode > 7) {
    throw Exception('覆盖安装目录失败，Robocopy 退出码：${result.exitCode}');
  }
}

void _scheduleCleanup({
  required String workDir,
  required String updaterDir,
  required String appDir,
}) {
  final systemTempPath = path.normalize(Directory.systemTemp.path);
  final normalizedWorkDir = path.normalize(workDir);
  final normalizedUpdaterDir = path.normalize(updaterDir);
  final normalizedAppDir = path.normalize(appDir);

  final cleanupTargets = <String>[];
  if (_isWithinDirectory(normalizedWorkDir, systemTempPath)) {
    cleanupTargets.add(normalizedWorkDir);
  }
  if (_isWithinDirectory(normalizedUpdaterDir, systemTempPath) &&
      normalizedUpdaterDir != normalizedAppDir) {
    cleanupTargets.add(normalizedUpdaterDir);
  }

  if (cleanupTargets.isEmpty) {
    return;
  }

  final cleanupParts = cleanupTargets
      .map((target) =>
          'if exist ${_cmdQuote(target)} rmdir /s /q ${_cmdQuote(target)}')
      .join(' & ');
  final cleanupCommand = 'ping 127.0.0.1 -n 3 > nul & $cleanupParts';

  Process.start(
    _cmdExecutable,
    ['/c', cleanupCommand],
    mode: ProcessStartMode.detached,
  );
}

bool _isWithinDirectory(String childPath, String parentPath) {
  return childPath == parentPath || path.isWithin(parentPath, childPath);
}

Future<void> _showErrorDialog(String message) async {
  await Process.run(_powerShellExecutable, [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-Command',
    '''
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show(
  ${_psQuote(message)},
  'Xii_Raw Graph 自动更新失败',
  [System.Windows.MessageBoxButton]::OK,
  [System.Windows.MessageBoxImage]::Error
) | Out-Null
''',
  ]);
}

String _psQuote(String value) {
  return "'${value.replaceAll("'", "''")}'";
}

String _cmdQuote(String value) {
  return '"${value.replaceAll('"', '""')}"';
}
