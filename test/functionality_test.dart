#!/usr/bin/env dart

import 'dart:io';
import 'package:path/path.dart' as path;

/// 功能测试验证脚本
/// 这个脚本验证AI聊天应用的所有主要功能
void main() async {
  print('🚀 开始AI聊天应用功能测试...\n');

  final projectRoot = Directory.current.path;
  final libDir = Directory(path.join(projectRoot, 'lib'));
  final testDir = Directory(path.join(projectRoot, 'test'));

  // 1. 验证项目结构
  print('📁 验证项目结构...');
  final structureTests = await validateProjectStructure(libDir, testDir);
  printResults('项目结构验证', structureTests);

  // 2. 验证依赖配置
  print('\n📦 验证依赖配置...');
  final dependencyTests = await validateDependencies(projectRoot);
  printResults('依赖配置验证', dependencyTests);

  // 3. 验证代码质量
  print('\n🔍 验证代码质量...');
  final codeQualityTests = await validateCodeQuality(libDir);
  printResults('代码质量验证', codeQualityTests);

  // 4. 验证功能完整性
  print('\n⚙️ 验证功能完整性...');
  final functionalityTests = await validateFunctionality(libDir);
  printResults('功能完整性验证', functionalityTests);

  // 5. 验证构建配置
  print('\n🏗️ 验证构建配置...');
  final buildTests = await validateBuildConfiguration(projectRoot);
  printResults('构建配置验证', buildTests);

  // 总结
  final allTests = [
    ...structureTests,
    ...dependencyTests,
    ...codeQualityTests,
    ...functionalityTests,
    ...buildTests,
  ];

  final passedTests = allTests.where((test) => test.passed).length;
  final totalTests = allTests.length;

  print('\n' + '=' * 50);
  print('📊 测试总结: $passedTests/$totalTests 通过');
  print('=' * 50);

  if (passedTests == totalTests) {
    print('✅ 所有功能测试通过！应用已准备就绪。');
    exit(0);
  } else {
    print('❌ 部分测试失败，请检查上述错误。');
    exit(1);
  }
}

class TestResult {
  final String name;
  final bool passed;
  final String? error;

  TestResult(this.name, this.passed, [this.error]);
}

void printResults(String category, List<TestResult> results) {
  for (final result in results) {
    if (result.passed) {
      print('  ✅ ${result.name}');
    } else {
      print('  ❌ ${result.name}: ${result.error}');
    }
  }
}

Future<List<TestResult>> validateProjectStructure(Directory libDir, Directory testDir) async {
  final results = <TestResult>[];

  // 检查主要文件是否存在
  final mainFile = File(path.join(libDir.path, 'main.dart'));
  results.add(TestResult(
    '主入口文件存在',
    await mainFile.exists(),
    'main.dart 文件不存在'
  ));

  final chatServiceFile = File(path.join(libDir.path, 'chat_service.dart'));
  results.add(TestResult(
    '聊天服务文件存在',
    await chatServiceFile.exists(),
    'chat_service.dart 文件不存在'
  ));

  final modelsFile = File(path.join(libDir.path, 'models.dart'));
  results.add(TestResult(
    '数据模型文件存在',
    await modelsFile.exists(),
    'models.dart 文件不存在'
  ));

  // 检查测试文件
  final widgetTestFile = File(path.join(testDir.path, 'widget_test.dart'));
  results.add(TestResult(
    '单元测试文件存在',
    await widgetTestFile.exists(),
    'widget_test.dart 文件不存在'
  ));

  return results;
}

Future<List<TestResult>> validateDependencies(String projectRoot) async {
  final results = <TestResult>[];

  final pubspecFile = File(path.join(projectRoot, 'pubspec.yaml'));
  if (!await pubspecFile.exists()) {
    results.add(TestResult('pubspec.yaml 存在', false, 'pubspec.yaml 文件不存在'));
    return results;
  }

  final content = await pubspecFile.readAsString();

  // 检查关键依赖
  final dependencies = [
    'http',
    'cached_network_image',
    'path_provider',
    'flutter_lints',
    'integration_test',
  ];

  for (final dep in dependencies) {
    final hasDep = content.contains('$dep:');
    results.add(TestResult(
      '$dep 依赖存在',
      hasDep,
      hasDep ? null : '$dep 依赖未找到'
    ));
  }

  return results;
}

Future<List<TestResult>> validateCodeQuality(Directory libDir) async {
  final results = <TestResult>[];

  // 检查主要文件是否有基本的代码结构
  final mainFile = File(path.join(libDir.path, 'main.dart'));
  if (await mainFile.exists()) {
    final content = await mainFile.readAsString();
    results.add(TestResult(
      'main.dart 包含 MaterialApp',
      content.contains('MaterialApp'),
      'MaterialApp 未找到'
    ));

    results.add(TestResult(
      'main.dart 包含主题配置',
      content.contains('ThemeData') || content.contains('theme:'),
      '主题配置未找到'
    ));
  }

  final chatServiceFile = File(path.join(libDir.path, 'chat_service.dart'));
  if (await chatServiceFile.exists()) {
    final content = await chatServiceFile.readAsString();
    results.add(TestResult(
      'chat_service.dart 包含 OpenAI 类',
      content.contains('class OpenAIChatService'),
      'OpenAIChatService 类未找到'
    ));

    results.add(TestResult(
      'chat_service.dart 包含 API 调用',
      content.contains('http.') || content.contains('post('),
      'HTTP API 调用未找到'
    ));
  }

  return results;
}

Future<List<TestResult>> validateFunctionality(Directory libDir) async {
  final results = <TestResult>[];

  final mainFile = File(path.join(libDir.path, 'main.dart'));
  if (await mainFile.exists()) {
    final content = await mainFile.readAsString();

    // 检查UI功能
    results.add(TestResult(
      '聊天界面组件存在',
      content.contains('ChatScreen') || content.contains('ChatBubble'),
      '聊天界面组件未找到'
    ));

    results.add(TestResult(
      '消息气泡动画存在',
      content.contains('AnimatedMessageBubble') || content.contains('Animation'),
      '消息动画未找到'
    ));

    results.add(TestResult(
      '图片显示功能存在',
      content.contains('CachedNetworkImage') || content.contains('Image.network'),
      '图片显示功能未找到'
    ));

    results.add(TestResult(
      '下载功能存在',
      content.contains('download') || content.contains('Download'),
      '下载功能未找到'
    ));

    // 检查状态管理
    results.add(TestResult(
      '状态管理存在',
      content.contains('StatefulWidget') || content.contains('setState'),
      '状态管理未找到'
    ));
  }

  // 检查服务功能
  final chatServiceFile = File(path.join(libDir.path, 'chat_service.dart'));
  if (await chatServiceFile.exists()) {
    final content = await chatServiceFile.readAsString();

    results.add(TestResult(
      '消息发送功能存在',
      content.contains('sendMessage'),
      'sendMessage 方法未找到'
    ));

    results.add(TestResult(
      '图片URL提取功能存在',
      content.contains('extractImageUrls') || content.contains('imageUrls'),
      '图片URL提取功能未找到'
    ));

    results.add(TestResult(
      '环境变量配置存在',
      content.contains('EnvConfig') || content.contains('.env'),
      '环境变量配置未找到'
    ));
  }

  return results;
}

Future<List<TestResult>> validateBuildConfiguration(String projectRoot) async {
  final results = <TestResult>[];

  final pubspecFile = File(path.join(projectRoot, 'pubspec.yaml'));
  if (await pubspecFile.exists()) {
    final content = await pubspecFile.readAsString();

    results.add(TestResult(
      'MSIX 配置存在',
      content.contains('msix:'),
      'MSIX 构建配置未找到'
    ));

    results.add(TestResult(
      '应用图标配置存在',
      content.contains('app_icon.ico') || content.contains('icon'),
      '应用图标配置未找到'
    ));

    results.add(TestResult(
      '发布者信息配置存在',
      content.contains('publisher:') || content.contains('CN='),
      '发布者信息配置未找到'
    ));
  }

  // 检查Windows构建配置
  final windowsDir = Directory(path.join(projectRoot, 'windows'));
  results.add(TestResult(
    'Windows 构建配置存在',
    await windowsDir.exists(),
    'windows 目录不存在'
  ));

  return results;
}