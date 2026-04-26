import 'dart:io';
import 'dart:convert';

/// 环境配置管理器
class EnvConfig {
  static Map<String, String> _envVars = {};

  /// 加载环境变量
  static void load() {
    try {
      final envFile = File('.env');
      if (envFile.existsSync()) {
        final lines = envFile.readAsLinesSync();
        for (final line in lines) {
          if (line.trim().isEmpty || line.startsWith('#')) continue;

          final parts = line.split('=');
          if (parts.length == 2) {
            final key = parts[0].trim();
            final value = parts[1].trim();
            _envVars[key] = value;
          }
        }
      }
    } catch (e) {
      print('Warning: Could not load .env file: $e');
    }
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
      throw Exception(
        'Missing required environment variable: $key\n'
        'Please set $key in your .env file or environment variables.\n'
        'See .env.example for configuration instructions.'
      );
    }
    return value;
  }
}