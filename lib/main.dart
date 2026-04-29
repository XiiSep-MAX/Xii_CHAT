import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'chat_service.dart';
import 'download_helper.dart';
import 'env_config.dart';
import 'models.dart';
import 'update_service.dart';

void main() {
  EnvConfig.load();
  runApp(const AIChatApp());
}

class AIChatApp extends StatelessWidget {
  const AIChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xii_Raw Graph Trial',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const String _appVersion = '1.2.3';

  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OpenAIChatService _chatService = OpenAIChatService();

  ChatImageAttachment? _selectedImageAttachment;
  ImageGenerationOptions _generationOptions = ImageGenerationOptions.defaults();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      final versionInfo =
          await UpdateService.checkForUpdates(currentVersion: _appVersion);
      if (versionInfo != null &&
          UpdateService.isUpdateAvailable(_appVersion, versionInfo.version)) {
        if (mounted) {
          _showUpdateDialog(versionInfo);
        }
      }
    } catch (e) {
      // 版本检查失败时继续使用应用
      print('版本检查异常: $e');
    }
  }

  void _showUpdateDialog(VersionInfo versionInfo) {
    showDialog(
      context: context,
      barrierDismissible: !versionInfo.isForced,
      builder: (context) => AlertDialog(
        title: const Text('🎉 发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最新版本: ${versionInfo.version}'),
            const SizedBox(height: 8),
            const Text('更新内容:'),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Text(versionInfo.releaseNotes),
              ),
            ),
          ],
        ),
        actions: [
          if (!versionInfo.isForced)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后提醒'),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _openDownloadUrl(versionInfo.downloadUrl);
                },
                child: const Text('打开下载页'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _downloadAndInstallUpdate(versionInfo);
                },
                child: const Text('下载更新'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstallUpdate(VersionInfo versionInfo) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final progressNotifier = ValueNotifier<UpdateDownloadProgress>(
      const UpdateDownloadProgress(
        phase: UpdateDownloadPhase.connecting,
        message: '正在准备下载更新包...',
        downloadedBytes: 0,
        totalBytes: null,
        attempt: 1,
        maxAttempts: 3,
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDownloadDialog(
        progressListenable: progressNotifier,
      ),
    );

    try {
      final result = await UpdateService.downloadAndInstallUpdate(
        versionInfo,
        onProgress: (progress) {
          progressNotifier.value = progress;
        },
      );
      if (result.success && result.shouldExitApplication) {
        progressNotifier.value = UpdateDownloadProgress(
          phase: UpdateDownloadPhase.restarting,
          message: result.message,
          downloadedBytes: progressNotifier.value.totalBytes ??
              progressNotifier.value.downloadedBytes,
          totalBytes: progressNotifier.value.totalBytes ??
              progressNotifier.value.downloadedBytes,
          attempt: progressNotifier.value.attempt,
          maxAttempts: progressNotifier.value.maxAttempts,
        );
        await Future<void>.delayed(const Duration(milliseconds: 900));
        exit(0);
      }

      if (navigator.mounted && navigator.canPop()) {
        navigator.pop();
      }
      if (!mounted) return;

      if (result.success) {
        final successTitle =
            result.message.contains('浏览器') ? '🌐 已切换浏览器下载' : '🚀 更新已准备好';
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(successTitle),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      } else {
        _showErrorDialog(result.message);
      }
    } catch (e) {
      if (navigator.mounted && navigator.canPop()) {
        navigator.pop();
      }
      if (!mounted) return;
      _showErrorDialog('下载过程中出现错误: $e');
    } finally {
      progressNotifier.dispose();
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ 更新失败'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDownloadUrl(String url) async {
    final opened = await UpdateService.openDownloadUrl(url);
    if (!mounted || opened) return;
    _showErrorDialog('无法打开更新链接，请手动访问：\n$url');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearMessages() {
    setState(() {
      _messages.clear();
    });
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showSnackBar('暂时无法读取所选图片，请更换一张后重试。');
        return;
      }

      setState(() {
        _selectedImageAttachment = ChatImageAttachment(
          bytes: bytes,
          name: file.name,
          mimeType: _resolveMimeType(file.name),
        );
      });
    } catch (e) {
      _showSnackBar('选择图片失败：$e');
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImageAttachment = null;
    });
  }

  void _updateAspectRatio(String aspectRatio) {
    setState(() {
      _generationOptions = _generationOptions.copyWith(
        aspectRatio: aspectRatio,
      );
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _resolveMimeType(String fileName) {
    final extensionIndex = fileName.lastIndexOf('.');
    if (extensionIndex < 0 || extensionIndex == fileName.length - 1) {
      return 'image/png';
    }

    switch (fileName.substring(extensionIndex + 1).toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/png';
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    final imageAttachment = _selectedImageAttachment;
    final requestOptions = _generationOptions.normalized();
    if (text.isEmpty && imageAttachment == null) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          role: Role.user,
          localImages: imageAttachment == null ? const [] : [imageAttachment],
          generationOptions: requestOptions,
        ),
      );
      _isSending = true;
      _controller.clear();
      _selectedImageAttachment = null;
    });
    _scrollToBottom();

    try {
      final response = await _chatService.sendMessage(
        prompt: text,
        options: requestOptions,
        imageAttachment: imageAttachment,
      );
      setState(() {
        _messages.add(
          ChatMessage(
            text: response.text,
            role: Role.bot,
            generatedImages: response.generatedImages,
            generationOptions: requestOptions,
          ),
        );
      });
      _scrollToBottom();
    } catch (error) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: '生成失败：${error.toString()}',
            role: Role.bot,
            generationOptions: requestOptions,
          ),
        );
      });
      _scrollToBottom();
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPrice =
        '\$${ImageGenerationOptions.unitPriceUsd.toStringAsFixed(2)}/张';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Xii_Raw Graph',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '试用版 v$_appVersion',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_sweep_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: '清空聊天',
            onPressed: _messages.isEmpty ? null : _clearMessages,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_messages.isEmpty)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.3),
                      Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withOpacity(0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.waving_hand_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '欢迎使用 Xii_Raw Graph 试用版',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '支持常规尺寸比例选择，价格统一 \$0.08/张。当前仅支持图片生成。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            if (_isSending)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI 正在生成图片...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return AnimatedMessageBubble(
                    key: ValueKey(message.createdAt),
                    message: message,
                    isNew: index == _messages.length - 1 && !_isSending,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GenerationOptionsPanel(
                    options: _generationOptions,
                    currentPrice: currentPrice,
                    onAspectRatioChanged:
                        _isSending ? null : _updateAspectRatio,
                  ),
                  const SizedBox(height: 12),
                  if (_selectedImageAttachment != null) ...[
                    _ComposerImagePreview(
                      attachment: _selectedImageAttachment!,
                      onRemove: _isSending ? null : _removeSelectedImage,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _selectedImageAttachment == null
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.3)
                              : Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.7),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: _isSending ? null : _pickImage,
                          tooltip: '选择图片',
                          icon: Icon(
                            _selectedImageAttachment == null
                                ? Icons.add_photo_alternate_outlined
                                : Icons.image_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _handleSend(),
                            enabled: !_isSending,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: _selectedImageAttachment == null
                                  ? '输入图片描述，例如：电影感海边日落、暖色调、超细节'
                                  : '输入描述，结合参考图一起生成...',
                              hintStyle: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withOpacity(0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isSending ? 48 : 80,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isSending
                                ? [Colors.grey.shade400, Colors.grey.shade500]
                                : [
                                    Colors.blue.shade500,
                                    Colors.purple.shade500,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: (_isSending ? Colors.grey : Colors.blue)
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSending ? null : _handleSend,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 48),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateDownloadDialog extends StatelessWidget {
  final ValueListenable<UpdateDownloadProgress> progressListenable;

  const _UpdateDownloadDialog({
    required this.progressListenable,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UpdateDownloadProgress>(
      valueListenable: progressListenable,
      builder: (context, progress, child) {
        final indicatorValue = progress.progress;
        final title = switch (progress.phase) {
          UpdateDownloadPhase.connecting => '连接下载服务器',
          UpdateDownloadPhase.downloading => '正在下载更新',
          UpdateDownloadPhase.retrying => '正在重试下载',
          UpdateDownloadPhase.finalizing => '整理下载结果',
          UpdateDownloadPhase.preparingInstall => '准备自动安装',
          UpdateDownloadPhase.restarting => '正在重启应用',
          UpdateDownloadPhase.fallback => '切换浏览器下载',
        };

        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: indicatorValue),
              const SizedBox(height: 16),
              Text(
                progress.message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                progress.progressLabel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '尝试次数：${progress.attempt}/${progress.maxAttempts}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnimatedMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isNew;

  const AnimatedMessageBubble({
    super.key,
    required this.message,
    this.isNew = false,
  });

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    if (widget.isNew) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ChatBubble(message: widget.message),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == Role.user;
    final bubbleColor = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceVariant;
    final textColor = isUser
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final avatar = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isUser
              ? [Colors.blue.shade400, Colors.purple.shade400]
              : [Colors.grey.shade400, Colors.grey.shade600],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        color: Colors.white,
        size: 20,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) avatar,
          if (!isUser) const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                if (message.generationOptions != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MessageOptionSummary(
                      options: message.generationOptions!,
                      alignEnd: isUser,
                    ),
                  ),
                if (message.text.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isUser
                            ? const Radius.circular(18)
                            : const Radius.circular(4),
                        bottomRight: isUser
                            ? const Radius.circular(4)
                            : const Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (message.hasImages) const SizedBox(height: 12),
                for (final localImage in message.localImages) ...[
                  _ChatImageFrame(
                    child: Image.memory(
                      localImage.bytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                for (final image in message.generatedImages) ...[
                  _ChatImageFrame(
                    child: image.hasBytes
                        ? Image.memory(
                            image.bytes!,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: image.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: double.infinity,
                              height: 240,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: double.infinity,
                              height: 240,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    color: Colors.grey.shade500,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '无法加载图片',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            fadeInDuration: const Duration(milliseconds: 300),
                            useOldImageOnUrlChange: true,
                          ),
                  ),
                  const SizedBox(height: 8),
                  _ImageDownloadAction(
                    image: image,
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 12),
          if (isUser) avatar,
        ],
      ),
    );
  }
}

class _ImageDownloadAction extends StatefulWidget {
  final GeneratedImageAsset image;
  final Alignment alignment;

  const _ImageDownloadAction({
    required this.image,
    required this.alignment,
  });

  @override
  State<_ImageDownloadAction> createState() => _ImageDownloadActionState();
}

class _ImageDownloadActionState extends State<_ImageDownloadAction> {
  ImageDownloadProgress? _progress;
  bool _isDownloading = false;

  Future<void> _handleDownload() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _progress = const ImageDownloadProgress(
        phase: ImageDownloadPhase.preparing,
        message: '正在准备下载...',
        downloadedBytes: 0,
        totalBytes: null,
      );
    });

    try {
      await downloadImagePlatform(
        widget.image,
        context: context,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
          });
        },
      );

      if ((_progress?.phase ?? ImageDownloadPhase.preparing) ==
          ImageDownloadPhase.completed) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;

    return Align(
      alignment: widget.alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: _isDownloading ? null : _handleDownload,
                icon: _isDownloading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress?.progress,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.download_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                label: Text(
                  _isDownloading ? '正在下载...' : '下载图片',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              if (_isDownloading && progress != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.progress,
                    minHeight: 6,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${progress.message} · ${progress.progressLabel}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerationOptionsPanel extends StatelessWidget {
  final ImageGenerationOptions options;
  final String currentPrice;
  final ValueChanged<String>? onAspectRatioChanged;

  const _GenerationOptionsPanel({
    required this.options,
    required this.currentPrice,
    this.onAspectRatioChanged,
  });

  @override
  Widget build(BuildContext context) {
    final availableRatios = ImageGenerationOptions.availableAspectRatios();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '本次生成参数',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '当前 $currentPrice',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final fieldWidth = compact ? constraints.maxWidth : 160.0;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: _OptionDropdown(
                      label: '尺寸比例',
                      value: options.aspectRatio,
                      items: availableRatios,
                      onChanged: onAspectRatioChanged,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            '当前仅保留常规尺寸比例选择，价格统一 $currentPrice。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String>? onChanged;

  const _OptionDropdown({
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.92),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged == null
          ? null
          : (value) {
              if (value != null) {
                onChanged!(value);
              }
            },
    );
  }
}

class _MessageOptionSummary extends StatelessWidget {
  final ImageGenerationOptions options;
  final bool alignEnd;

  const _MessageOptionSummary({
    required this.options,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
      spacing: 8,
      runSpacing: 8,
      children: [
        _SummaryChip(
          icon: Icons.crop_rounded,
          label: options.aspectRatio,
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerImagePreview extends StatelessWidget {
  final ChatImageAttachment attachment;
  final VoidCallback? onRemove;

  const _ComposerImagePreview({
    required this.attachment,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              attachment.bytes,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '已选择参考图',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attachment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: '移除图片',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _ChatImageFrame extends StatelessWidget {
  final Widget child;

  const _ChatImageFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 300,
            maxWidth: 350,
          ),
          child: child,
        ),
      ),
    );
  }
}
