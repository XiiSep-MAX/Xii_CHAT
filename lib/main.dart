import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_service.dart';
import 'download_helper.dart';
import 'env_config.dart';
import 'license_service.dart';
import 'local_storage_service.dart';
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
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: const Color(0xFF1C4C4A),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD3E8E4),
      onPrimaryContainer: const Color(0xFF10211F),
      secondary: const Color(0xFF8C6C3C),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFEEDFC7),
      onSecondaryContainer: const Color(0xFF2B2113),
      tertiary: const Color(0xFF5D7385),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFD9E3EC),
      onTertiaryContainer: const Color(0xFF1B2A34),
      error: const Color(0xFFB9382A),
      onError: Colors.white,
      errorContainer: const Color(0xFFF9DBD6),
      onErrorContainer: const Color(0xFF3C120D),
      surface: const Color(0xFFF6F1E8),
      onSurface: const Color(0xFF182224),
      surfaceContainerHighest: const Color(0xFFE8E1D6),
      onSurfaceVariant: const Color(0xFF5E6A6C),
      outline: const Color(0xFFBEC6C4),
      outlineVariant: const Color(0xFFD8DED9),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFF1D2628),
      onInverseSurface: const Color(0xFFF4F0E8),
      inversePrimary: const Color(0xFF9CC7C2),
      surfaceTint: const Color(0xFF1C4C4A),
    );

    return MaterialApp(
      title: 'Xii_Raw Graph Trial',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFEEE7DB),
        fontFamily: 'Segoe UI',
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.88),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: colorScheme.outline.withValues(alpha: 0.16),
          space: 1,
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1E2A2A),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.22),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.86),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.55),
              width: 1.4,
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
  static const String _appVersion = '1.2.5';
  static const String _privacyAcknowledgedKey = 'privacy_acknowledged_v1';
  static const String _retainReferenceImagesKey = 'retain_reference_images_v1';
  static const String _contactWechatId = '123456';
  static const List<String> _blockedPromptKeywords = [
    '未成年裸体',
    '未成年人裸体',
    '儿童裸体',
    '幼女',
    '幼童',
    '强奸',
    '轮奸',
    '乱伦',
    '兽交',
    '恋童',
    '极端血腥',
    '肢解',
    '斩首',
    '虐杀',
    '分尸',
    '尸体特写',
    '炸弹制作',
    '制毒',
    '恐怖袭击教程',
    '证件伪造',
    '护照伪造',
    'deepfake porn',
    'child porn',
    'rape',
    'incest',
    'bestiality',
    'gore',
    'beheading',
    'dismemberment',
    'how to make a bomb',
    'fake passport',
  ];
  static const List<String> _unsafeReferenceEditKeywords = [
    '去衣',
    '脱衣',
    '裸体化',
    '衣服去掉',
    'remove clothes',
    'undress',
    'nude edit',
  ];

  final List<ChatMessage> _messages = [];
  final List<ChatSessionInfo> _sessions = [];
  final List<GeneratedImageHistoryEntry> _generatedImageHistory = [];
  final List<SessionSwitchLogEntry> _sessionSwitchLogs = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OpenAIChatService _chatService = OpenAIChatService();
  final LocalStorageService _storageService = LocalStorageService.instance;
  final LicenseService _licenseService = LicenseService.instance;

  ChatSessionInfo? _activeSession;
  LicenseStatus? _licenseStatus;
  ChatImageAttachment? _selectedImageAttachment;
  ImageGenerationOptions _generationOptions = ImageGenerationOptions.defaults();
  bool _retainReferenceImagesLocally = true;
  bool _isSending = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeLocalState();
    _checkForUpdates();
  }

  Future<void> _initializeLocalState() async {
    try {
      await _storageService.initialize();
      var licenseStatus = await _licenseService.initialize();
      licenseStatus = await _licenseService.refreshLicenseStatus();

      var sessions = await _storageService.loadSessions();
      ChatSessionInfo? activeSession =
          await _storageService.loadLatestSession();

      if (sessions.isEmpty || activeSession == null) {
        activeSession = await _storageService.createSession();
        sessions = await _storageService.loadSessions();
      } else {
        await _storageService.activateSession(activeSession.id);
        sessions = await _storageService.loadSessions();
        activeSession =
            _findSessionById(sessions, activeSession.id) ?? activeSession;
      }

      final messages = await _storageService.loadMessages(activeSession.id);
      final imageHistory = await _storageService.loadGeneratedImageHistory();
      final switchLogs =
          await _storageService.loadSessionSwitchLogs(limit: 120);
      final privacyAcknowledged =
          await _storageService.readAppState(_privacyAcknowledgedKey);
      final retainReferenceImagesValue =
          await _storageService.readAppState(_retainReferenceImagesKey);

      if (!mounted) return;
      setState(() {
        _activeSession = activeSession;
        _licenseStatus = licenseStatus;
        _retainReferenceImagesLocally = retainReferenceImagesValue != 'false';
        _messages
          ..clear()
          ..addAll(messages);
        _sessions
          ..clear()
          ..addAll(sessions);
        _generatedImageHistory
          ..clear()
          ..addAll(imageHistory);
        _sessionSwitchLogs
          ..clear()
          ..addAll(switchLogs);
        _isInitializing = false;
      });
      if (privacyAcknowledged != 'true') {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _showPrivacyNoticeDialog();
        });
      }
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });
      _showErrorDialog('本地数据初始化失败：$e');
    }
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

  Future<void> _showPrivacyNoticeDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('数据与隐私说明'),
        content: const SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '为了支持多会话、生图历史和授权状态，本应用会在本地保存聊天记录、图片元数据和授权信息。',
              ),
              SizedBox(height: 10),
              Text(
                '使用 AI 生成功能时，提示词和参考图会发送到云端服务处理。',
              ),
              SizedBox(height: 10),
              Text(
                '你可以稍后在应用内通过“数据与隐私”入口查看说明，并清空全部本地数据。',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _openDownloadUrl('https://xiimax.top/privacy.html');
            },
            child: const Text('查看隐私政策'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _storageService.writeAppState(
                _privacyAcknowledgedKey,
                'true',
              );
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacyAndDataSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.78,
        child: StatefulBuilder(
          builder: (context, setSheetState) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '数据与隐私',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '本应用当前会在本地保存：会话列表、聊天记录、AI 生图历史、会话切换记录、授权状态。使用 AI 生成功能时，提示词和参考图会发送到云端服务处理。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '当前数据保留策略：',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. 本地会话和历史默认持续保留，直到你手动删除。\n2. 授权状态会保存在本地，便于下次启动恢复。\n3. 应用不会自动把完整本地历史同步到云端。\n4. 你可以手动清空全部本地数据。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          await _openDownloadUrl(
                            'https://xiimax.top/privacy.html',
                          );
                        },
                        child: const Text('打开隐私政策'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          await _openDownloadUrl(
                            'https://xiimax.top/support.html',
                          );
                        },
                        child: const Text('打开支持页'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('本地保存参考图原始数据'),
                    subtitle: const Text(
                      '关闭后，参考图不会写入本地数据库，只在当前发送时使用，可减少敏感图片在本地落库。',
                    ),
                    value: _retainReferenceImagesLocally,
                    onChanged: (value) async {
                      await _storageService.writeAppState(
                        _retainReferenceImagesKey,
                        value ? 'true' : 'false',
                      );
                      if (!mounted) return;
                      setState(() {
                        _retainReferenceImagesLocally = value;
                      });
                      setSheetState(() {});
                    },
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '危险操作：清空全部本地数据',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '这会删除本地会话、消息、生图历史、授权状态和隐私确认状态。清空后应用会回到初始状态。',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.tonal(
                          onPressed: () =>
                              Navigator.of(context).pop('settings'),
                          child: const Text('打开详细设置页'),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonal(
                          onPressed: () => Navigator.of(context).pop('clear'),
                          child: const Text('清空全部本地数据'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (action == 'clear') {
      await _clearAllLocalData();
    } else if (action == 'settings') {
      await _openPrivacySettingsPage();
    }
  }

  Future<void> _openPrivacySettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _PrivacySettingsPage(
          retainReferenceImagesLocally: _retainReferenceImagesLocally,
          onToggleRetainReferenceImages: (value) async {
            await _storageService.writeAppState(
              _retainReferenceImagesKey,
              value ? 'true' : 'false',
            );
            if (!mounted) return;
            setState(() {
              _retainReferenceImagesLocally = value;
            });
          },
          onOpenPrivacyPolicy: () async {
            await _openDownloadUrl('https://xiimax.top/privacy.html');
          },
          onOpenSupportPage: () async {
            await _openDownloadUrl('https://xiimax.top/support.html');
          },
          onClearAllData: _clearAllLocalData,
        ),
      ),
    );
  }

  Future<void> _clearAllLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空全部本地数据'),
        content: const Text(
          '此操作会删除本地会话、聊天记录、生图历史、授权状态和隐私确认状态，且无法恢复。确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _storageService.clearAllLocalData();
      final newSession = await _storageService.createSession();
      final sessions = await _storageService.loadSessions();
      final switchLogs =
          await _storageService.loadSessionSwitchLogs(limit: 120);
      final licenseStatus = await _licenseService.initialize();

      if (!mounted) return;
      setState(() {
        _activeSession = newSession;
        _licenseStatus = licenseStatus;
        _messages.clear();
        _sessions
          ..clear()
          ..addAll(sessions);
        _generatedImageHistory.clear();
        _sessionSwitchLogs
          ..clear()
          ..addAll(switchLogs);
        _selectedImageAttachment = null;
        _controller.clear();
      });
      _showSnackBar('本地数据已清空。');
      await _showPrivacyNoticeDialog();
    } catch (error) {
      if (!mounted) return;
      _showErrorDialog('清空全部本地数据失败：$error');
    }
  }

  Future<void> _refreshLicenseStatus() async {
    final status = await _licenseService.refreshLicenseStatus();
    if (!mounted) return;
    setState(() {
      _licenseStatus = status;
    });
  }

  Future<void> _showAuthorContactDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('联系作者'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 184,
                height: 184,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEE6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(
                          alpha: 0.14,
                        ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 74,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '二维码占位',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '微信号：$_contactWechatId',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '如需开通授权、联系作者或获取支持，可以先通过微信联系。后续你可以把这里替换成真实二维码图片。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: _contactWechatId),
              );
              if (!mounted) return;
              _showSnackBar('微信号已复制');
            },
            child: const Text('复制微信号'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showActivationDialog() async {
    final currentStatus = _licenseStatus ?? await _licenseService.initialize();
    final controller = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('激活高级功能'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentStatus.summaryText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (currentStatus.isDevelopmentBypass)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '当前未配置 LICENSE_API_BASE_URL，应用会继续按开发模式运行。配置 Worker 后，这里会进入真实激活校验流程。',
                      ),
                    )
                  else
                    TextField(
                      controller: controller,
                      autofocus: true,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: '输入激活码',
                        hintText: '例如：XII-2026-XXXX-XXXX',
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              if (currentStatus.isPremium)
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          final nextStatus =
                              await _licenseService.clearLicense();
                          if (!mounted) return;
                          setState(() {
                            _licenseStatus = nextStatus;
                          });
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          _showSnackBar('本地授权状态已清除。');
                        },
                  child: const Text('清除授权'),
                ),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('关闭'),
              ),
              if (!currentStatus.isDevelopmentBypass)
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final code = controller.text.trim();
                          if (code.isEmpty) {
                            _showSnackBar('请输入激活码。');
                            return;
                          }
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          final result =
                              await _licenseService.activateCode(code);
                          if (!mounted) return;
                          setState(() {
                            _licenseStatus = result.status;
                          });
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          _showSnackBar(result.message);
                        },
                  child: Text(isSubmitting ? '正在激活...' : '立即激活'),
                ),
            ],
          ),
        );
      },
    );
    controller.dispose();
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

  ChatSessionInfo? _findSessionById(List<ChatSessionInfo> sessions, int id) {
    for (final session in sessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  Future<void> _openSession(int sessionId, {bool recordSwitch = true}) async {
    if (_isSending) {
      _showSnackBar('当前正在生成图片，请稍后再切换会话。');
      return;
    }

    try {
      if (recordSwitch) {
        await _storageService.activateSession(sessionId);
      }

      final messages = await _storageService.loadMessages(sessionId);
      final sessions = await _storageService.loadSessions();
      final history = await _storageService.loadGeneratedImageHistory();
      final switchLogs =
          await _storageService.loadSessionSwitchLogs(limit: 120);
      final activeSession = _findSessionById(sessions, sessionId);

      if (!mounted || activeSession == null) return;
      setState(() {
        _activeSession = activeSession;
        _messages
          ..clear()
          ..addAll(messages);
        _sessions
          ..clear()
          ..addAll(sessions);
        _generatedImageHistory
          ..clear()
          ..addAll(history);
        _sessionSwitchLogs
          ..clear()
          ..addAll(switchLogs);
        _selectedImageAttachment = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('切换会话失败：$e');
    }
  }

  Future<void> _createSession() async {
    if (_isSending) {
      _showSnackBar('当前正在生成图片，请稍后再新建会话。');
      return;
    }

    try {
      final session = await _storageService.createSession();
      final sessions = await _storageService.loadSessions();
      final history = await _storageService.loadGeneratedImageHistory();
      final switchLogs =
          await _storageService.loadSessionSwitchLogs(limit: 120);
      final activeSession = _findSessionById(sessions, session.id) ?? session;

      if (!mounted) return;
      setState(() {
        _activeSession = activeSession;
        _messages.clear();
        _sessions
          ..clear()
          ..addAll(sessions);
        _generatedImageHistory
          ..clear()
          ..addAll(history);
        _sessionSwitchLogs
          ..clear()
          ..addAll(switchLogs);
        _controller.clear();
        _selectedImageAttachment = null;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('新建会话失败：$e');
    }
  }

  Future<void> _renameSession(ChatSessionInfo session) async {
    if (_isSending) {
      _showSnackBar('当前正在生成图片，请稍后再重命名会话。');
      return;
    }

    final controller = TextEditingController(text: session.title);
    final renamedTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            hintText: '输入新的会话名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();

    final nextTitle = renamedTitle?.trim();
    if (nextTitle == null || nextTitle.isEmpty || nextTitle == session.title) {
      return;
    }

    try {
      await _storageService.renameSession(session.id, nextTitle);
      final sessions = await _storageService.loadSessions();
      final refreshedActiveSession = _activeSession?.id == session.id
          ? _findSessionById(sessions, session.id)
          : _activeSession;

      if (!mounted) return;
      setState(() {
        _sessions
          ..clear()
          ..addAll(sessions);
        if (refreshedActiveSession != null) {
          _activeSession = refreshedActiveSession;
        }
      });
      _showSnackBar('会话已重命名。');
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('重命名会话失败：$e');
    }
  }

  Future<void> _deleteSession(ChatSessionInfo session) async {
    if (_isSending) {
      _showSnackBar('当前正在生成图片，请稍后再删除会话。');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('将永久删除“${session.title}”及其消息和生图历史，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      final deletedActiveSession = _activeSession?.id == session.id;
      await _storageService.deleteSession(session.id);

      var sessions = await _storageService.loadSessions();
      ChatSessionInfo? nextActiveSession = _activeSession;
      if (deletedActiveSession) {
        nextActiveSession = await _storageService.loadLatestSession();
        if (nextActiveSession == null) {
          nextActiveSession = await _storageService.createSession();
          sessions = await _storageService.loadSessions();
        } else {
          await _storageService.activateSession(nextActiveSession.id);
          sessions = await _storageService.loadSessions();
          nextActiveSession =
              _findSessionById(sessions, nextActiveSession.id) ??
                  nextActiveSession;
        }
      } else {
        nextActiveSession = _activeSession == null
            ? null
            : _findSessionById(sessions, _activeSession!.id);
      }

      final messages = nextActiveSession == null
          ? const <ChatMessage>[]
          : await _storageService.loadMessages(nextActiveSession.id);
      final history = await _storageService.loadGeneratedImageHistory();
      final switchLogs =
          await _storageService.loadSessionSwitchLogs(limit: 120);

      if (!mounted) return;
      setState(() {
        _sessions
          ..clear()
          ..addAll(sessions);
        _generatedImageHistory
          ..clear()
          ..addAll(history);
        _sessionSwitchLogs
          ..clear()
          ..addAll(switchLogs);
        _activeSession = nextActiveSession;
        _messages
          ..clear()
          ..addAll(messages);
        _selectedImageAttachment = null;
      });
      _showSnackBar('会话已删除。');
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('删除会话失败：$e');
    }
  }

  Future<void> _clearMessages() async {
    final activeSession = _activeSession;
    if (activeSession == null) return;
    if (_isSending) {
      _showSnackBar('当前正在生成图片，请稍后再清空会话。');
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空当前会话'),
        content: Text('将清空“${activeSession.title}”中的所有消息和生图记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (shouldClear != true) {
      return;
    }

    try {
      await _storageService.clearSessionMessages(activeSession.id);
      final sessions = await _storageService.loadSessions();
      final history = await _storageService.loadGeneratedImageHistory();
      final switchLogs =
          await _storageService.loadSessionSwitchLogs(limit: 120);
      final refreshedSession =
          _findSessionById(sessions, activeSession.id) ?? activeSession;

      if (!mounted) return;
      setState(() {
        _messages.clear();
        _sessions
          ..clear()
          ..addAll(sessions);
        _generatedImageHistory
          ..clear()
          ..addAll(history);
        _sessionSwitchLogs
          ..clear()
          ..addAll(switchLogs);
        _activeSession = refreshedSession;
      });
      _showSnackBar('当前会话已清空。');
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('清空会话失败：$e');
    }
  }

  Future<void> _showGeneratedImageHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _GeneratedImageHistorySheet(
          entries: _generatedImageHistory,
          onOpenSession: (sessionId) async {
            Navigator.of(sheetContext).pop();
            await _openSession(sessionId);
          },
        ),
      ),
    );
  }

  Future<void> _showSessionSwitchLogs() async {
    final sessionTitleById = {
      for (final session in _sessions) session.id: session.title,
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.8,
        child: _SessionSwitchLogSheet(
          entries: _sessionSwitchLogs,
          sessionTitleById: sessionTitleById,
        ),
      ),
    );
  }

  Widget _buildSessionPanel({
    required bool closeDrawerOnAction,
  }) {
    return _SessionSidebar(
      sessions: _sessions,
      activeSession: _activeSession,
      isBusy: _isSending || _isInitializing,
      onSelectSession: (session) async {
        if (closeDrawerOnAction) {
          Navigator.of(context).pop();
        }
        await _openSession(session.id);
      },
      onCreateSession: () async {
        if (closeDrawerOnAction) {
          Navigator.of(context).pop();
        }
        await _createSession();
      },
      onOpenImageHistory: () async {
        if (closeDrawerOnAction) {
          Navigator.of(context).pop();
        }
        await _showGeneratedImageHistory();
      },
      onOpenSwitchLogs: () async {
        if (closeDrawerOnAction) {
          Navigator.of(context).pop();
        }
        await _showSessionSwitchLogs();
      },
      onRenameSession: (session) async {
        if (closeDrawerOnAction) {
          Navigator.of(context).pop();
        }
        await _renameSession(session);
      },
      onDeleteSession: (session) async {
        if (closeDrawerOnAction) {
          Navigator.of(context).pop();
        }
        await _deleteSession(session);
      },
    );
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
    final activeSession = _activeSession;
    var licenseStatus = _licenseStatus ?? await _licenseService.initialize();
    final text = _controller.text.trim();
    final imageAttachment = _selectedImageAttachment;
    final requestOptions = _generationOptions.normalized();
    if (activeSession == null || (text.isEmpty && imageAttachment == null)) {
      return;
    }

    final localSafetyMessage = _evaluateLocalSafety(
      text: text,
      hasReferenceImage: imageAttachment != null,
    );
    if (localSafetyMessage != null) {
      _showSnackBar(localSafetyMessage);
      return;
    }

    if (!licenseStatus.canUseGeneration) {
      await _showActivationDialog();
      licenseStatus = _licenseStatus ?? await _licenseService.initialize();
      if (!licenseStatus.canUseGeneration) {
        return;
      }
    }

    final userMessage = ChatMessage(
      text: text,
      role: Role.user,
      localImages: imageAttachment == null
          ? const []
          : (_retainReferenceImagesLocally ? [imageAttachment] : const []),
      generationOptions: requestOptions,
    );

    try {
      final savedUserMessage = await _storageService.saveMessage(
        sessionId: activeSession.id,
        message: userMessage,
      );
      await _storageService.maybeUpdateSessionTitleFromMessage(
        activeSession.id,
        text,
      );
      final sessionsAfterUserSave = await _storageService.loadSessions();
      final refreshedActiveSession =
          _findSessionById(sessionsAfterUserSave, activeSession.id) ??
              activeSession;

      if (!mounted) return;
      setState(() {
        _licenseStatus = licenseStatus;
        _messages.add(savedUserMessage);
        _sessions
          ..clear()
          ..addAll(sessionsAfterUserSave);
        _activeSession = refreshedActiveSession;
        _isSending = true;
        _controller.clear();
        _selectedImageAttachment = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('保存用户消息失败：$e');
      return;
    }

    try {
      final response = await _chatService.sendMessage(
        prompt: text,
        options: requestOptions,
        imageAttachment: imageAttachment,
      );
      if (!licenseStatus.isPremium) {
        licenseStatus = await _licenseService.consumeTrialUse();
      } else {
        licenseStatus = await _licenseService.refreshLicenseStatus();
      }
      final botMessage = ChatMessage(
        text: response.text,
        role: Role.bot,
        generatedImages: response.generatedImages,
        generationOptions: requestOptions,
      );
      final savedBotMessage = await _storageService.saveMessage(
        sessionId: activeSession.id,
        message: botMessage,
      );
      final sessions = await _storageService.loadSessions();
      final history = await _storageService.loadGeneratedImageHistory();
      final refreshedActiveSession =
          _findSessionById(sessions, activeSession.id) ?? activeSession;

      if (!mounted) return;
      setState(() {
        _licenseStatus = licenseStatus;
        _messages.add(savedBotMessage);
        _sessions
          ..clear()
          ..addAll(sessions);
        _generatedImageHistory
          ..clear()
          ..addAll(history);
        _activeSession = refreshedActiveSession;
      });
      _scrollToBottom();
    } catch (error) {
      final errorMessage = ChatMessage(
        text: '生成失败：${error.toString()}',
        role: Role.bot,
        generationOptions: requestOptions,
      );
      try {
        final savedErrorMessage = await _storageService.saveMessage(
          sessionId: activeSession.id,
          message: errorMessage,
        );
        final sessions = await _storageService.loadSessions();
        final refreshedActiveSession =
            _findSessionById(sessions, activeSession.id) ?? activeSession;

        if (!mounted) return;
        setState(() {
          _licenseStatus = licenseStatus;
          _messages.add(savedErrorMessage);
          _sessions
            ..clear()
            ..addAll(sessions);
          _activeSession = refreshedActiveSession;
        });
      } catch (saveError) {
        if (!mounted) return;
        _showErrorDialog('保存错误消息失败：$saveError');
      }
      _scrollToBottom();
    } finally {
      try {
        final switchLogs =
            await _storageService.loadSessionSwitchLogs(limit: 120);
        if (!mounted) return;
        setState(() {
          _isSending = false;
          _sessionSwitchLogs
            ..clear()
            ..addAll(switchLogs);
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String? _evaluateLocalSafety({
    required String text,
    required bool hasReferenceImage,
  }) {
    final normalized = text.toLowerCase();
    for (final keyword in _blockedPromptKeywords) {
      if (normalized.contains(keyword.toLowerCase())) {
        return '当前提示词包含不适合生成的内容，请调整后再试。';
      }
    }

    if (hasReferenceImage) {
      for (final keyword in _unsafeReferenceEditKeywords) {
        if (normalized.contains(keyword.toLowerCase())) {
          return '当前参考图编辑描述风险较高，请避免使用去衣、裸体化等要求。';
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.of(context).size.width >= 1120;
    final activeSession = _activeSession;
    final licenseStatus = _licenseStatus;
    final licenseBadgeLabel = licenseStatus?.badgeLabel ?? '授权读取中';

    return Scaffold(
      drawer: isWideLayout
          ? null
          : Drawer(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              width: 320,
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                child: _buildSessionPanel(closeDrawerOnAction: true),
              ),
            ),
      appBar: AppBar(
        leading: isWideLayout
            ? null
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: '会话面板',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E4F4D),
                    Color(0xFF7A6741),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E4F4D).withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Xii_Raw Graph',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (activeSession != null)
                          Text(
                            activeSession.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      '$licenseBadgeLabel · v$_appVersion',
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
        actions: [
          IconButton(
            icon: Icon(
              Icons.privacy_tip_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: '数据与隐私',
            onPressed: _isInitializing ? null : _showPrivacyAndDataSheet,
          ),
          IconButton(
            icon: Icon(
              Icons.verified_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: '激活与授权',
            onPressed: _isInitializing ? null : _showActivationDialog,
          ),
          IconButton(
            icon: Icon(
              Icons.add_comment_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: '新建会话',
            onPressed: _isInitializing ? null : _createSession,
          ),
          IconButton(
            icon: Icon(
              Icons.photo_library_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'AI 生图历史',
            onPressed: _isInitializing ? null : _showGeneratedImageHistory,
          ),
          IconButton(
            icon: Icon(
              Icons.swap_horizontal_circle_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: '切换记录',
            onPressed: _isInitializing ? null : _showSessionSwitchLogs,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_sweep_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: '清空聊天',
            onPressed:
                _messages.isEmpty || _isInitializing ? null : _clearMessages,
          ),
        ],
      ),
      body: SafeArea(
        child: _isInitializing
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '正在初始化本地会话数据库...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  if (isWideLayout)
                    SizedBox(
                      width: 320,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 0, 18),
                        child: _buildSessionPanel(closeDrawerOnAction: false),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 32,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: _buildChatWorkspace(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildChatWorkspace() {
    final activeSession = _activeSession;
    final licenseStatus = _licenseStatus;

    return Column(
      children: [
        if (activeSession != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _WorkspaceStatusStrip(
              session: activeSession,
              licenseStatus: licenseStatus,
              onRefresh: _refreshLicenseStatus,
              onContactAuthor: _showAuthorContactDialog,
              onActivate: _showActivationDialog,
            ),
          ),
        if (_messages.isEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.96),
                  const Color(0xFFF6EEE2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(
                      alpha: 0.12,
                    ),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 34,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  activeSession == null
                      ? (licenseStatus?.isPremium ?? false)
                          ? '欢迎使用 Xii_Raw Graph 高级版'
                          : '欢迎使用 Xii_Raw Graph 试用版'
                      : '欢迎回到「${activeSession.title}」',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  licenseStatus?.summaryText ??
                      '现在支持本地 SQLite 会话保存、多会话切换记录，以及 AI 生图历史回看。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        if (_isSending)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0E7D8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
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
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return AnimatedMessageBubble(
                key: ValueKey(message.id ?? message.createdAt),
                message: message,
                isNew: index == _messages.length - 1 && !_isSending,
              );
            },
          ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F3EA),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedImageAttachment != null) ...[
                _ComposerImagePreview(
                  attachment: _selectedImageAttachment!,
                  onRemove: _isSending ? null : _removeSelectedImage,
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _selectedImageAttachment == null
                          ? Colors.white.withValues(alpha: 0.82)
                          : Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.14),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      onPressed: _isSending || _activeSession == null
                          ? null
                          : _pickImage,
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
                        color: Colors.white.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.14),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSend(),
                        enabled: !_isSending &&
                            !_isInitializing &&
                            _activeSession != null &&
                            (licenseStatus?.canUseGeneration ?? true),
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: _selectedImageAttachment == null
                              ? '输入图片描述，例如：电影感海边日落、暖色调、超细节'
                              : '输入描述，结合参考图一起生成...',
                          hintStyle: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.58),
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
                            : const [Color(0xFF214F4C), Color(0xFF7B6842)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (_isSending ? Colors.grey : Colors.blue)
                              .withValues(alpha: 0.24),
                          blurRadius: 12,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _isSending || _activeSession == null
                            ? null
                            : _handleSend,
                        child: Center(
                          child: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  '发送',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (licenseStatus != null && !licenseStatus.isPremium) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '目前\$0.08一张。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
          UpdateDownloadPhase.verifying => '校验更新包',
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

class _WorkspaceStatusStrip extends StatelessWidget {
  final ChatSessionInfo session;
  final LicenseStatus? licenseStatus;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onContactAuthor;
  final Future<void> Function() onActivate;

  const _WorkspaceStatusStrip({
    required this.session,
    required this.licenseStatus,
    required this.onRefresh,
    required this.onContactAuthor,
    required this.onActivate,
  });

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final status = licenseStatus;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4ECE0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '消息 ${session.messageCount} 条 · 切换 ${session.switchCount} 次 · 最近 ${_formatTime(session.sortTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onRefresh,
              child: const Text('刷新'),
            ),
            FilledButton.tonal(
              onPressed: onContactAuthor,
              child: const Text('联系作者'),
            ),
            FilledButton.tonal(
              onPressed: onActivate,
              child: const Text('授权'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionSidebar extends StatelessWidget {
  final List<ChatSessionInfo> sessions;
  final ChatSessionInfo? activeSession;
  final bool isBusy;
  final ValueChanged<ChatSessionInfo> onSelectSession;
  final ValueChanged<ChatSessionInfo> onRenameSession;
  final ValueChanged<ChatSessionInfo> onDeleteSession;
  final VoidCallback onCreateSession;
  final VoidCallback onOpenImageHistory;
  final VoidCallback onOpenSwitchLogs;

  const _SessionSidebar({
    required this.sessions,
    required this.activeSession,
    required this.isBusy,
    required this.onSelectSession,
    required this.onRenameSession,
    required this.onDeleteSession,
    required this.onCreateSession,
    required this.onOpenImageHistory,
    required this.onOpenSwitchLogs,
  });

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.layers_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '本地会话',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: isBusy ? null : onCreateSession,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('新建对话'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenImageHistory,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('生图历史'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenSwitchLogs,
                        icon: const Icon(Icons.swap_calls_outlined),
                        label: const Text('切换记录'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      '暂无会话',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sessions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final selected = session.id == activeSession?.id;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onSelectSession(session),
                          borderRadius: BorderRadius.circular(18),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFE8EFE9)
                                  : const Color(0xFFF7F3EC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.18)
                                    : Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        session.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: selected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (selected)
                                          Icon(
                                            Icons.radio_button_checked_rounded,
                                            size: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        PopupMenuButton<String>(
                                          tooltip: '会话操作',
                                          onSelected: (value) {
                                            switch (value) {
                                              case 'rename':
                                                onRenameSession(session);
                                                break;
                                              case 'delete':
                                                onDeleteSession(session);
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem<String>(
                                              value: 'rename',
                                              child: Text('重命名'),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'delete',
                                              child: Text('删除会话'),
                                            ),
                                          ],
                                          icon: Icon(
                                            Icons.more_horiz_rounded,
                                            size: 18,
                                            color: selected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer
                                                    .withValues(alpha: 0.8)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '消息 ${session.messageCount} 条 · 切换 ${session.switchCount} 次',
                                  style: TextStyle(
                                    color: selected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withValues(alpha: 0.85)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '最近使用 ${_formatTime(session.sortTime)}',
                                  style: TextStyle(
                                    color: selected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withValues(alpha: 0.78)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedImageHistorySheet extends StatelessWidget {
  final List<GeneratedImageHistoryEntry> entries;
  final ValueChanged<int> onOpenSession;

  const _GeneratedImageHistorySheet({
    required this.entries,
    required this.onOpenSession,
  });

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 52,
            height: 5,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI 生图历史',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                Text(
                  '${entries.length} 张',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      '还没有 AI 生图历史',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: 310,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(22),
                                ),
                                child: entry.image.hasBytes
                                    ? Image.memory(
                                        entry.image.bytes!,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: entry.image.imageUrl!,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.sessionTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    entry.messageText.trim().isEmpty
                                        ? '无文本提示词'
                                        : entry.messageText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${entry.aspectRatio ?? '未知比例'} · ${_formatTime(entry.createdAt)}',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          onOpenSession(entry.sessionId),
                                      icon:
                                          const Icon(Icons.open_in_new_rounded),
                                      label: const Text('打开会话'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionSwitchLogSheet extends StatelessWidget {
  final List<SessionSwitchLogEntry> entries;
  final Map<int, String> sessionTitleById;

  const _SessionSwitchLogSheet({
    required this.entries,
    required this.sessionTitleById,
  });

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 52,
            height: 5,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(
                  Icons.swap_horizontal_circle_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '会话切换记录',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                Text(
                  '${entries.length} 条',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      '还没有切换记录',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: entries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.28),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.8),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.alt_route_rounded,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sessionTitleById[entry.sessionId] ??
                                        '会话 #${entry.sessionId}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '切换时间 ${_formatTime(entry.switchedAt)}',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
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

  void _copyMessageText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(content: Text('文字已复制')),
    );
  }

  void _showImagePreview(BuildContext context, Widget image) {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: '关闭图片预览',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ImagePreviewDialog(image: image);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        );
      },
    );
  }

  Widget _buildGeneratedImageWidget(
    GeneratedImageAsset image, {
    required BoxFit fit,
  }) {
    if (image.hasBytes) {
      return Image.memory(
        image.bytes!,
        fit: fit,
        filterQuality: FilterQuality.high,
      );
    }

    return CachedNetworkImage(
      imageUrl: image.imageUrl!,
      fit: fit,
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
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == Role.user;
    final bubbleColor =
        isUser ? const Color(0xFF214F4C) : const Color(0xFFF4EEE4);
    final textColor =
        isUser ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final avatar = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isUser
              ? const [Color(0xFF214F4C), Color(0xFF7B6842)]
              : const [Color(0xFFE7DDD0), Color(0xFFCFC2B1)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        color: isUser ? Colors.white : const Color(0xFF4E5C5A),
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
                if (message.text.isNotEmpty)
                  _CopyableMessageContent(
                    text: message.text,
                    bubbleColor: bubbleColor,
                    textColor: textColor,
                    isUser: isUser,
                    onCopy: () => _copyMessageText(context, message.text),
                  ),
                if (message.hasImages) const SizedBox(height: 12),
                for (final localImage in message.localImages) ...[
                  _ChatImageFrame(
                    onTap: () => _showImagePreview(
                      context,
                      Image.memory(
                        localImage.bytes,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    child: Image.memory(
                      localImage.bytes,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                for (final image in message.generatedImages) ...[
                  _ChatImageFrame(
                    onTap: () => _showImagePreview(
                      context,
                      _buildGeneratedImageWidget(
                        image,
                        fit: BoxFit.contain,
                      ),
                    ),
                    child: _buildGeneratedImageWidget(
                      image,
                      fit: BoxFit.cover,
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

class _CopyableMessageContent extends StatelessWidget {
  final String text;
  final Color bubbleColor;
  final Color textColor;
  final bool isUser;
  final VoidCallback onCopy;

  const _CopyableMessageContent({
    required this.text,
    required this.bubbleColor,
    required this.textColor,
    required this.isUser,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
          bottomLeft:
              isUser ? const Radius.circular(22) : const Radius.circular(8),
          bottomRight:
              isUser ? const Radius.circular(8) : const Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                height: 1.56,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onCopy,
            tooltip: '复制文字',
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
            splashRadius: 18,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.content_copy_rounded,
              size: 18,
              color: textColor.withValues(alpha: 0.78),
            ),
          ),
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
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 8),
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
        color: const Color(0xFFF5EFE5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
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
  final VoidCallback? onTap;

  const _ChatImageFrame({
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageFrame = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 300,
              maxWidth: 350,
            ),
            child: child,
          ),
          if (onTap != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.58),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final previewableChild = onTap == null
        ? imageFrame
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: imageFrame,
            ),
          );

    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: previewableChild,
      ),
    );
  }
}

class _ImagePreviewDialog extends StatelessWidget {
  final Widget image;

  const _ImagePreviewDialog({required this.image});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: ColoredBox(
                color: Colors.black.withOpacity(0.92),
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: size.width * 0.94,
                        maxHeight: size.height * 0.84,
                      ),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.5,
                        child: image,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '关闭预览',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: SafeArea(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.52),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      '点击空白处关闭，支持滚轮或双指缩放',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySettingsPage extends StatelessWidget {
  final bool retainReferenceImagesLocally;
  final Future<void> Function(bool value) onToggleRetainReferenceImages;
  final Future<void> Function() onOpenPrivacyPolicy;
  final Future<void> Function() onOpenSupportPage;
  final Future<void> Function() onClearAllData;

  const _PrivacySettingsPage({
    required this.retainReferenceImagesLocally,
    required this.onToggleRetainReferenceImages,
    required this.onOpenPrivacyPolicy,
    required this.onOpenSupportPage,
    required this.onClearAllData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据与隐私'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text(
            '本地数据说明',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '当前应用会在本地保存：会话、消息、生图历史、会话切换记录和授权状态。AI 生图请求中的提示词和参考图会发送到云端服务处理。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF6F0E6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.1),
              ),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              title: const Text('本地保存参考图原始数据'),
              subtitle: const Text(
                '关闭后，参考图不会再写入本地数据库，可减少敏感图片在本地落库；已保存的旧参考图仍需手动清空。',
              ),
              value: retainReferenceImagesLocally,
              onChanged: (value) async {
                await onToggleRetainReferenceImages(value);
              },
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '数据保留策略',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '1. 本地会话和历史默认持续保留，直到你手动删除。\n'
            '2. 授权状态会保存在本地，便于下次启动恢复。\n'
            '3. 应用不会自动把完整本地历史同步到云端。\n'
            '4. 你可以清空全部本地数据，使应用回到初始状态。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonal(
                onPressed: onOpenPrivacyPolicy,
                child: const Text('打开隐私政策'),
              ),
              FilledButton.tonal(
                onPressed: onOpenSupportPage,
                child: const Text('打开支持页'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(
                    alpha: 0.36,
                  ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color:
                    Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '清空全部本地数据',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '会删除本地会话、聊天记录、生图历史、授权状态和隐私确认状态。此操作不可恢复。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: onClearAllData,
                  child: const Text('立即清空本地数据'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
