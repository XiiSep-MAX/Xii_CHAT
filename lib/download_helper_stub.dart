import 'package:flutter/material.dart';

Future<void> downloadImagePlatform(String url, {BuildContext? context}) async {
  if (context == null) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    const SnackBar(content: Text('当前平台暂不支持图片下载。')),
  );
}
