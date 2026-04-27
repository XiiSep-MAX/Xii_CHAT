import 'dart:io';

import 'package:path/path.dart' as path;

/// 环境配置管理器
class EnvConfig {
  static final Map<String, String> _envVars = {};

  /// 加载环境变量
  static void load() {
    _envVars.clear();

    try {
      for (final envFile in _candidateEnvFiles()) {
        if (!envFile.existsSync()) {
          continue;
        }

        final lines = envFile.readAsLinesSync();
        for (final line in lines) {
          if (line.trim().isEmpty || line.startsWith('#')) continue;

          final separatorIndex = line.indexOf('=');
          if (separatorIndex > 0) {
            final key = line.substring(0, separatorIndex).trim();
            final value = line.substring(separatorIndex + 1).trim();
            _envVars[key] = value;
          }
        }
      }
    } catch (e) {
      stderr.writeln('Warning: Could not load .env file: $e');
    }
  }

  static List<File> _candidateEnvFiles() {
    final candidates = <String>{
      path.join(Directory.current.path, '.env'),
      path.join(File(Platform.resolvedExecutable).parent.path, '.env'),
    };

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      candidates.add(path.join(localAppData, 'Xii_Raw Graph', '.env'));
    }

    return candidates.map(File.new).toList();
  }

  /// 获取环境变量值
  static String? get(String key) {
    // 优先使用系统环境变量
    final systemValue = Platform.environment[key];
    if (systemValue != null && systemValue.isNotEmpty) {
      return systemValue;
    }

    // 其次使用 .env 文件中的值
    return _envVars[key];
  }

  /// 获取必需的环境变量（如果不存在会抛出异常）
  static String getRequired(String key) {
    final value = get(key);
    if (value == null || value.isEmpty || value == 'your-api-key-here') {
      throw Exception('Missing required environment variable: $key\n'
          'Please set $key in your .env file or environment variables.\n'
          'See .env.example for configuration instructions.');
    }
    return value;
  }
}
