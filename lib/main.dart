import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

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

class _AppChromePalette {
  static const Color bg = Color(0xFF020617);
  static const Color panel = Color(0xFF0B1120);
  static const Color panelSoft = Color(0xFF0F172A);
  static const Color panelElevated = Color(0xFF111C34);
  static const Color panelAccent = Color(0xFF172554);
  static const Color border = Color(0xFF223257);
  static const Color borderSoft = Color(0xFF1B2946);
  static const Color text = Color(0xFFE5EEFf);
  static const Color textMuted = Color(0xFF8EA4C8);
  static const Color textSoft = Color(0xFF647BA3);
  static const Color accent = Color(0xFF60A5FA);
  static const Color accentStrong = Color(0xFF1D4ED8);
  static const Color cyan = Color(0xFF38BDF8);

  static LinearGradient get appBackground => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF020617),
          Color(0xFF081226),
          Color(0xFF0F172A),
          Color(0xFF172554),
        ],
        stops: [0.0, 0.28, 0.72, 1.0],
      );

  static LinearGradient get panelGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0F172A),
          Color(0xFF111C34),
        ],
      );
}

class _OutpaintRequest {
  final String prompt;
  final double leftRatio;
  final double rightRatio;
  final double topRatio;
  final double bottomRatio;

  const _OutpaintRequest({
    required this.prompt,
    required this.leftRatio,
    required this.rightRatio,
    required this.topRatio,
    required this.bottomRatio,
  });
}

class _PreparedEditImages {
  final ChatImageAttachment sourceImage;
  final ChatImageAttachment maskImage;

  const _PreparedEditImages({
    required this.sourceImage,
    required this.maskImage,
  });
}

class _SourceImageInfo {
  final ChatImageAttachment attachment;
  final int width;
  final int height;

  const _SourceImageInfo({
    required this.attachment,
    required this.width,
    required this.height,
  });
}

class _InpaintRequest {
  final String prompt;
  final List<Offset> normalizedPoints;
  final double normalizedBrushRadius;

  const _InpaintRequest({
    required this.prompt,
    required this.normalizedPoints,
    required this.normalizedBrushRadius,
  });
}

class _PreviewThumbnailData {
  final Uint8List bytes;
  final int width;
  final int height;

  const _PreviewThumbnailData({
    required this.bytes,
    required this.width,
    required this.height,
  });

  double get aspectRatio => height == 0 ? 1 : width / height;
}

class _PreviewThumbnailJob {
  final Uint8List bytes;
  final int targetWidth;

  const _PreviewThumbnailJob({
    required this.bytes,
    required this.targetWidth,
  });
}

_PreviewThumbnailData? _buildPreviewThumbnailBytes(_PreviewThumbnailJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) {
    return null;
  }

  final resized = decoded.width > job.targetWidth
      ? img.copyResize(decoded, width: job.targetWidth)
      : decoded;

  return _PreviewThumbnailData(
    bytes: Uint8List.fromList(
      img.encodeJpg(
        resized,
        quality: 84,
      ),
    ),
    width: resized.width,
    height: resized.height,
  );
}

class AIChatApp extends StatelessWidget {
  const AIChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _AppChromePalette.accentStrong,
      onPrimary: Colors.white,
      primaryContainer: _AppChromePalette.panelAccent,
      onPrimaryContainer: _AppChromePalette.text,
      secondary: _AppChromePalette.accent,
      onSecondary: const Color(0xFF03111F),
      secondaryContainer: const Color(0xFF10213D),
      onSecondaryContainer: const Color(0xFFD7EBFF),
      tertiary: _AppChromePalette.cyan,
      onTertiary: const Color(0xFF03111F),
      tertiaryContainer: const Color(0xFF082F49),
      onTertiaryContainer: const Color(0xFFD8F3FF),
      error: const Color(0xFFB42318),
      onError: Colors.white,
      errorContainer: const Color(0xFF4C1111),
      onErrorContainer: const Color(0xFFFECACA),
      surface: _AppChromePalette.panel,
      onSurface: _AppChromePalette.text,
      surfaceContainerHighest: _AppChromePalette.panelElevated,
      onSurfaceVariant: _AppChromePalette.textMuted,
      outline: _AppChromePalette.border,
      outlineVariant: _AppChromePalette.borderSoft,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: _AppChromePalette.text,
      onInverseSurface: _AppChromePalette.bg,
      inversePrimary: const Color(0xFFD7EBFF),
      surfaceTint: _AppChromePalette.accentStrong,
    );

    return MaterialApp(
      title: 'Xii_Raw Graph Trial',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: _AppChromePalette.bg,
        fontFamily: 'Segoe UI',
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        cardTheme: CardThemeData(
          color: _AppChromePalette.panelElevated,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: colorScheme.outline.withValues(alpha: 0.3),
          space: 1,
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _AppChromePalette.panelElevated,
          contentTextStyle: const TextStyle(
            color: _AppChromePalette.text,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _AppChromePalette.accentStrong,
            foregroundColor: Colors.white,
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
              color: colorScheme.outline.withValues(alpha: 0.9),
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
          fillColor: _AppChromePalette.panelSoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.9),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.9),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: _AppChromePalette.accent.withValues(alpha: 0.95),
              width: 1.4,
            ),
          ),
        ),
      ),
      home: const _SplashIntroGate(),
    );
  }
}

class _SplashIntroGate extends StatefulWidget {
  const _SplashIntroGate();

  @override
  State<_SplashIntroGate> createState() => _SplashIntroGateState();
}

class _SplashIntroGateState extends State<_SplashIntroGate>
    with TickerProviderStateMixin {
  static const Duration _minimumIntroDuration = Duration(milliseconds: 3600);
  static const Duration _maximumIntroWait = Duration(seconds: 12);

  late final AnimationController _controller;
  late final AnimationController _ambientController;
  bool _minimumDurationElapsed = false;
  bool _initializationComplete = false;
  bool _forcedIntroDismiss = false;
  bool _loadingExtendedBeyondMinimum = false;
  bool _showIntro = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _minimumIntroDuration,
    )..forward();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    Future<void>.delayed(_minimumIntroDuration, () {
      if (!mounted) return;
      _minimumDurationElapsed = true;
      _loadingExtendedBeyondMinimum = !_initializationComplete;
      _tryDismissIntro();
    });
    Future<void>.delayed(_maximumIntroWait, () {
      if (!mounted || !_showIntro || _initializationComplete) {
        return;
      }
      _forcedIntroDismiss = true;
      _minimumDurationElapsed = true;
      _tryDismissIntro();
    });
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleInitializationChanged(bool isInitializing) {
    final completed = !isInitializing;
    if (_initializationComplete == completed) {
      return;
    }
    _initializationComplete = completed;
    _tryDismissIntro();
  }

  void _tryDismissIntro() {
    if (!mounted || !_showIntro) return;
    if (!_minimumDurationElapsed ||
        (!_initializationComplete && !_forcedIntroDismiss)) {
      return;
    }
    setState(() {
      _showIntro = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ChatScreen(
          key: const ValueKey('chat-home'),
          showInitializationIndicator: false,
          onInitializationChanged: _handleInitializationChanged,
        ),
        IgnorePointer(
          ignoring: !_showIntro,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
            opacity: _showIntro ? 1 : 0,
            child: _SplashIntroScene(
              timelineController: _controller,
              ambientController: _ambientController,
              initializationComplete: _initializationComplete,
              loadingExtendedBeyondMinimum: _loadingExtendedBeyondMinimum,
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashIntroScene extends StatelessWidget {
  final AnimationController timelineController;
  final AnimationController ambientController;
  final bool initializationComplete;
  final bool loadingExtendedBeyondMinimum;

  const _SplashIntroScene({
    required this.timelineController,
    required this.ambientController,
    required this.initializationComplete,
    required this.loadingExtendedBeyondMinimum,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([timelineController, ambientController]),
        builder: (context, child) {
          final effectiveTimelineValue = loadingExtendedBeyondMinimum
              ? math.min(timelineController.value, 0.78)
              : timelineController.value;
          final entrance = Curves.easeOutExpo.transform(
            (effectiveTimelineValue / 0.36).clamp(0.0, 1.0),
          );
          final settle = Curves.easeInOut.transform(
            ((effectiveTimelineValue - 0.18) / 0.5).clamp(0.0, 1.0),
          );
          final scan = loadingExtendedBeyondMinimum
              ? ambientController.value
              : Curves.easeInOutSine.transform(
                  ((effectiveTimelineValue - 0.12) / 0.76).clamp(0.0, 1.0),
                );
          final outro = loadingExtendedBeyondMinimum
              ? 0.0
              : Curves.easeInCubic.transform(
                  ((effectiveTimelineValue - 0.78) / 0.22).clamp(0.0, 1.0),
                );

          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF020617),
                  Color(0xFF06111F),
                  Color(0xFF081A2F),
                  Color(0xFF0A2744),
                ],
                stops: [0.0, 0.34, 0.76, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _IntroBackgroundPainter(
                        scanProgress: scan,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 64,
                  left: 28,
                  child: RepaintBoundary(
                    child: Opacity(
                      opacity: 0.55 + (0.45 * entrance),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'XII RAW GRAPH',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.96),
                              fontSize: 14,
                              letterSpacing: 4.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'HOLOGRAPHIC CREATIVE CONSOLE',
                            style: TextStyle(
                              color: const Color(0xFF7DD3FC)
                                  .withValues(alpha: 0.72),
                              fontSize: 10.5,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 62,
                  right: 28,
                  child: RepaintBoundary(
                    child: Opacity(
                      opacity: 0.42 + (0.58 * entrance),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF67E8F9)
                                .withValues(alpha: 0.22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22D3EE)
                                  .withValues(alpha: 0.10),
                              blurRadius: 18,
                              spreadRadius: -6,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SYSTEM READY',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.52),
                                fontSize: 10,
                                letterSpacing: 1.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              initializationComplete
                                  ? '100%'
                                  : '${(math.max(
                                        effectiveTimelineValue,
                                        timelineController.value.clamp(0.0, 1.0),
                                      ) * 100).round()}%',
                              style: const TextStyle(
                                color: Color(0xFFBAE6FD),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 30,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stageWidth =
                              math.min(constraints.maxWidth * 0.82, 760.0);
                          final stageHeight =
                              math.min(constraints.maxHeight * 0.44, 360.0);
                          return Column(
                            children: [
                              const Spacer(),
                              Transform.translate(
                                offset: Offset(0, 16 * (1 - entrance)),
                                child: Opacity(
                                  opacity: 1 - (outro * 1.15).clamp(0.0, 1.0),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        width: stageWidth,
                                        height: stageHeight,
                                        child: RepaintBoundary(
                                          child: _IntroStage(
                                            entrance: entrance,
                                            settle: settle,
                                            scan: scan,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 38),
                                      Transform.translate(
                                        offset: Offset(0, 18 * (1 - entrance)),
                                        child: Opacity(
                                          opacity: entrance,
                                          child: Column(
                                            children: [
                                              ShaderMask(
                                                shaderCallback: (bounds) {
                                                  return const LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      Color(0xFFE0F2FE),
                                                      Color(0xFFA5F3FC),
                                                      Color(0xFF67E8F9),
                                                    ],
                                                  ).createShader(bounds);
                                                },
                                                child: const Text(
                                                  '全息创作中枢已就绪',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 40,
                                                    height: 1.08,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: -1.2,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(
                                                  maxWidth: 760,
                                                ),
                                                child: Text(
                                                  'Xii_Raw Graph 把本地会话记忆、AI 生图历史、参考图工作流、未完成任务续跑整合进一套桌面创作控制台。重开应用，也能无缝接回上次生成现场。',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.76),
                                                    fontSize: 15,
                                                    height: 1.55,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 18),
                                              Wrap(
                                                alignment: WrapAlignment.center,
                                                spacing: 10,
                                                runSpacing: 10,
                                                children: const [
                                                  _IntroFeatureChip(
                                                    label: '本地会话自动恢复',
                                                  ),
                                                  _IntroFeatureChip(
                                                    label: '未完成生成继续轮询',
                                                  ),
                                                  _IntroFeatureChip(
                                                    label: '参考图扩图 / 局部重绘',
                                                  ),
                                                  _IntroFeatureChip(
                                                    label: '提示词模板与生图历史',
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(flex: 2),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Opacity(
                                  opacity: 0.5 + (0.5 * settle),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        width: 180,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(999),
                                          child: LinearProgressIndicator(
                                            value: initializationComplete
                                                ? 1
                                                : timelineController.value,
                                            minHeight: 4,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.10),
                                            valueColor:
                                                const AlwaysStoppedAnimation(
                                              Color(0xFF93C5FD),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        initializationComplete
                                            ? '本地中枢已恢复，可以继续创作'
                                            : '正在同步本地会话、授权状态、任务轮询与图像记录',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.46),
                                          fontSize: 11.8,
                                          letterSpacing: 1.4,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IntroStage extends StatelessWidget {
  final double entrance;
  final double settle;
  final double scan;

  const _IntroStage({
    required this.entrance,
    required this.settle,
    required this.scan,
  });

  @override
  Widget build(BuildContext context) {
    final shellTilt = (1 - settle) * 0.5;
    final shellTurn = (1 - entrance) * 0.78;
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, 46 * (1 - entrance)),
          child: Opacity(
            opacity: 0.52 * settle,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF22D3EE).withValues(alpha: 0.34),
                    const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateX(0.92 - shellTilt)
            ..rotateZ(-0.22),
          child: Container(
            width: 470,
            height: 470,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF67E8F9).withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: CustomPaint(
              painter: _IntroRingPainter(scan: scan),
            ),
          ),
        ),
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateX(0.28 - (0.15 * settle))
            ..rotateY(-shellTurn + 0.06 * math.sin(settle * math.pi * 1.6)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              _IntroPanel(
                width: 440,
                height: 244,
                offset: const Offset(-12, 22),
                colorA: const Color(0xFF071424),
                colorB: const Color(0xFF0A2744),
                borderColor: const Color(0xFF67E8F9).withValues(alpha: 0.14),
                shadowColor: const Color(0xFF22D3EE).withValues(alpha: 0.18),
                child: const _IntroPanelGrid(),
              ),
              _IntroPanel(
                width: 368,
                height: 206,
                offset: Offset(
                  12 * math.sin(scan * math.pi * 1.2),
                  -10 + (10 * (1 - entrance)),
                ),
                colorA: const Color(0xFF050B16),
                colorB: const Color(0xFF10243D),
                borderColor: const Color(0xFFBAE6FD).withValues(alpha: 0.18),
                shadowColor: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
                child: _IntroCenterPanel(scan: scan),
              ),
              _IntroPanel(
                width: 164,
                height: 108,
                offset: Offset(-168 - (34 * (1 - settle)), -98),
                colorA: const Color(0xFF071424),
                colorB: const Color(0xFF11324E),
                borderColor: const Color(0xFF67E8F9).withValues(alpha: 0.16),
                shadowColor: const Color(0xFF06B6D4).withValues(alpha: 0.16),
                child: _MiniPanel(label: '本地会话', value: '自动续接'),
              ),
              _IntroPanel(
                width: 164,
                height: 108,
                offset: Offset(170 + (30 * (1 - settle)), -82),
                colorA: const Color(0xFF071826),
                colorB: const Color(0xFF103B52),
                borderColor: const Color(0xFF93C5FD).withValues(alpha: 0.16),
                shadowColor: const Color(0xFF38BDF8).withValues(alpha: 0.16),
                child: _MiniPanel(label: '生图任务', value: '断点续跑'),
              ),
              _IntroPanel(
                width: 164,
                height: 108,
                offset: Offset(-152 - (28 * (1 - settle)), 108),
                colorA: const Color(0xFF08131E),
                colorB: const Color(0xFF134E4A),
                borderColor: const Color(0xFF5EEAD4).withValues(alpha: 0.18),
                shadowColor: const Color(0xFF14B8A6).withValues(alpha: 0.16),
                child: _MiniPanel(label: '参考图工作流', value: '扩图 / 重绘'),
              ),
              _IntroPanel(
                width: 164,
                height: 108,
                offset: Offset(184 + (30 * (1 - settle)), 102),
                colorA: const Color(0xFF111827),
                colorB: const Color(0xFF1E3A8A),
                borderColor: const Color(0xFFC4B5FD).withValues(alpha: 0.18),
                shadowColor: const Color(0xFFA78BFA).withValues(alpha: 0.16),
                child: _MiniPanel(label: '素材沉淀', value: '历史与模板'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntroPanel extends StatelessWidget {
  final double width;
  final double height;
  final Offset offset;
  final Color colorA;
  final Color colorB;
  final Color borderColor;
  final Color shadowColor;
  final Widget child;

  const _IntroPanel({
    required this.width,
    required this.height,
    required this.offset,
    required this.colorA,
    required this.colorB,
    required this.borderColor,
    required this.shadowColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorA.withValues(alpha: 0.94),
                colorB.withValues(alpha: 0.82),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 34,
                spreadRadius: -10,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: Stack(
              children: [
                Positioned.fill(child: child),
                const Positioned.fill(child: _IntroHudCorners()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPanelGrid extends StatelessWidget {
  const _IntroPanelGrid();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _IntroPanelGridPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _IntroCenterPanel extends StatelessWidget {
  final double scan;

  const _IntroCenterPanel({
    required this.scan,
  });

  @override
  Widget build(BuildContext context) {
    final activeIndex = scan < 0.25
        ? 0
        : scan < 0.5
            ? 1
            : scan < 0.75
                ? 2
                : 3;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF67E8F9).withValues(alpha: 0.07),
                  Colors.transparent,
                  const Color(0xFF0EA5E9).withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          top: 16,
          child: Text(
            'CREATIVE SYSTEM OVERVIEW',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11,
              letterSpacing: 2.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          top: 50,
          bottom: 44,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 150;
              if (compact) {
                final tileWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: tileWidth,
                      child: _StartupMetricCompactCard(
                        label: '会话记忆',
                        value: '自动恢复',
                        isActive: activeIndex == 0,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _StartupMetricCompactCard(
                        label: '生成任务',
                        value: '继续轮询',
                        isActive: activeIndex == 1,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _StartupMetricCompactCard(
                        label: '参考图',
                        value: '扩图 / 重绘',
                        isActive: activeIndex == 2,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _StartupMetricCompactCard(
                        label: '素材沉淀',
                        value: '历史 / 模板',
                        isActive: activeIndex == 3,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _IntroWavePainter(scan: scan),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StartupMetricRow(
                    label: '本地会话记忆',
                    value: '自动恢复',
                    isActive: activeIndex == 0,
                  ),
                  const SizedBox(height: 8),
                  _StartupMetricRow(
                    label: '未完成生成',
                    value: '继续轮询',
                    isActive: activeIndex == 1,
                  ),
                  const SizedBox(height: 8),
                  _StartupMetricRow(
                    label: '参考图工作流',
                    value: '扩图 / 重绘',
                    isActive: activeIndex == 2,
                  ),
                  const SizedBox(height: 8),
                  _StartupMetricRow(
                    label: '提示词与图库沉淀',
                    value: '历史 / 模板',
                    isActive: activeIndex == 3,
                  ),
                ],
              );
            },
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 16,
          child: Row(
            children: [
              _StatusDot(color: const Color(0xFF34D399), pulse: scan),
              const SizedBox(width: 8),
              Text(
                initializationLabel(scan),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String initializationLabel(double scan) {
    if (scan < 0.25) {
      return '正在连接本地创作中枢';
    }
    if (scan < 0.5) {
      return '正在恢复最近会话与生成记录';
    }
    if (scan < 0.75) {
      return '正在接管未完成任务与参考图状态';
    }
    return '正在校验授权状态并准备回到工作台';
  }
}

class _MiniPanel extends StatelessWidget {
  final String label;
  final String value;

  const _MiniPanel({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 10.5,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE0F2FE),
              fontSize: 17,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isActive;

  const _StartupMetricRow({
    required this.label,
    required this.value,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isActive ? const Color(0xFF67E8F9) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isActive ? 0.08 : 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: isActive ? 0.34 : 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isActive ? 1 : 0.45),
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.42),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: accent.withValues(alpha: isActive ? 0.96 : 0.58),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupMetricCompactCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isActive;

  const _StartupMetricCompactCard({
    required this.label,
    required this.value,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isActive ? const Color(0xFF67E8F9) : Colors.white;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isActive ? 0.08 : 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: isActive ? 0.34 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent.withValues(alpha: isActive ? 0.96 : 0.78),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroFeatureChip extends StatelessWidget {
  final String label;

  const _IntroFeatureChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF67E8F9).withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.84),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IntroHudCorners extends StatelessWidget {
  const _IntroHudCorners();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _IntroHudCornersPainter(),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final double pulse;

  const _StatusDot({
    required this.color,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final scale = 0.85 + (0.35 * math.sin(pulse * math.pi));
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.42),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroBackgroundPainter extends CustomPainter {
  final double scanProgress;

  const _IntroBackgroundPainter({
    required this.scanProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0EA5E9).withValues(alpha: 0.30),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.78, size.height * 0.22),
          radius: size.shortestSide * 0.42,
        ),
      );
    canvas.drawRect(Offset.zero & size, glowPaint);

    final glowPaintLeft = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF14B8A6).withValues(alpha: 0.14),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.18, size.height * 0.82),
          radius: size.shortestSide * 0.46,
        ),
      );
    canvas.drawRect(Offset.zero & size, glowPaintLeft);

    final gridPaint = Paint()
      ..color = const Color(0xFFBAE6FD).withValues(alpha: 0.07)
      ..strokeWidth = 1;
    const spacing = 42.0;
    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      final dx = x + (scanProgress * 10);
      canvas.drawLine(
        Offset(dx, 0),
        Offset(dx - 30, size.height),
        gridPaint,
      );
    }
    for (double y = 0; y < size.height + spacing; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF67E8F9).withValues(alpha: 0.10);
    for (int i = 0; i < 4; i++) {
      final radius = size.shortestSide * (0.18 + (i * 0.11));
      canvas.drawCircle(
        Offset(size.width * 0.72, size.height * 0.46),
        radius,
        ringPaint,
      );
    }

    final beamX =
        ui.lerpDouble(-size.width * 0.3, size.width * 1.1, scanProgress)!;
    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFFE0F2FE).withValues(alpha: 0.12),
          const Color(0xFF67E8F9).withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(beamX - 80, 0, 160, size.height),
      );
    canvas.drawRect(Rect.fromLTWH(beamX - 80, 0, 160, size.height), beamPaint);

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF020617).withValues(alpha: 0.18),
          const Color(0xFF020617).withValues(alpha: 0.62),
        ],
        stops: const [0.45, 0.78, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _IntroBackgroundPainter oldDelegate) {
    return oldDelegate.scanProgress != scanProgress;
  }
}

class _IntroRingPainter extends CustomPainter {
  final double scan;

  const _IntroRingPainter({
    required this.scan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final center = size.center(Offset.zero);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFBAE6FD).withValues(alpha: 0.10);
    canvas.drawCircle(center, size.width * 0.22, basePaint);
    canvas.drawCircle(center, size.width * 0.32, basePaint);
    canvas.drawCircle(center, size.width * 0.42, basePaint);

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0xFF67E8F9).withValues(alpha: 0.22);
    for (int i = 0; i < 24; i++) {
      final angle = (math.pi * 2 * i / 24) + (scan * math.pi * 0.35);
      final start = Offset(
        center.dx + math.cos(angle) * size.width * 0.45,
        center.dy + math.sin(angle) * size.width * 0.45,
      );
      final end = Offset(
        center.dx + math.cos(angle) * size.width * 0.49,
        center.dy + math.sin(angle) * size.width * 0.49,
      );
      canvas.drawLine(start, end, dashPaint);
    }

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF67E8F9).withValues(alpha: 0.0),
          const Color(0xFF67E8F9).withValues(alpha: 0.95),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 0.62, 1.0],
        transform: GradientRotation(scan * math.pi * 2.0),
      ).createShader(
        Rect.fromCircle(center: center, radius: size.width * 0.42),
      );
    canvas.drawCircle(center, size.width * 0.42, activePaint);
  }

  @override
  bool shouldRepaint(covariant _IntroRingPainter oldDelegate) {
    return oldDelegate.scan != scan;
  }
}

class _IntroPanelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFBAE6FD).withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (double x = 18; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 16; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final accentPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF22D3EE).withValues(alpha: 0.28),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.52, size.width, 34));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.52, size.width, 34),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IntroWavePainter extends CustomPainter {
  final double scan;

  const _IntroWavePainter({
    required this.scan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final rect = Offset.zero & size;
    final safeWidth = size.width <= 0 ? 1.0 : size.width;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF22D3EE).withValues(alpha: 0.14),
          const Color(0xFF38BDF8).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      fill,
    );

    final path = Path();
    for (int i = 0; i <= size.width; i++) {
      final x = i.toDouble();
      final baseY = size.height * 0.54;
      final y = baseY +
          math.sin((x / safeWidth) * math.pi * 2.6 + (scan * math.pi * 2.1)) *
              14 +
          math.cos((x / safeWidth) * math.pi * 6.4 - (scan * math.pi * 1.4)) *
              6;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..color = const Color(0xFF67E8F9).withValues(alpha: 0.30);
    canvas.drawPath(path, glow);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFBAE6FD),
          const Color(0xFF67E8F9),
        ],
      ).createShader(rect);
    canvas.drawPath(path, line);

    final markerX = size.width * scan;
    final markerY = size.height * 0.54 +
        math.sin((markerX / safeWidth) * math.pi * 2.6 +
                (scan * math.pi * 2.1)) *
            14 +
        math.cos((markerX / safeWidth) * math.pi * 6.4 -
                (scan * math.pi * 1.4)) *
            6;
    final markerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(markerX, markerY), 3.5, markerPaint);
  }

  @override
  bool shouldRepaint(covariant _IntroWavePainter oldDelegate) {
    return oldDelegate.scan != scan;
  }
}

class _IntroHudCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF67E8F9).withValues(alpha: 0.34)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    const segment = 18.0;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(27),
    );
    canvas.drawLine(
      Offset(r.left + 10, r.top + 8),
      Offset(r.left + 10 + segment, r.top + 8),
      paint,
    );
    canvas.drawLine(
      Offset(r.left + 8, r.top + 10),
      Offset(r.left + 8, r.top + 10 + segment),
      paint,
    );

    canvas.drawLine(
      Offset(r.right - 10 - segment, r.top + 8),
      Offset(r.right - 10, r.top + 8),
      paint,
    );
    canvas.drawLine(
      Offset(r.right - 8, r.top + 10),
      Offset(r.right - 8, r.top + 10 + segment),
      paint,
    );

    canvas.drawLine(
      Offset(r.left + 8, r.bottom - 10 - segment),
      Offset(r.left + 8, r.bottom - 10),
      paint,
    );
    canvas.drawLine(
      Offset(r.left + 10, r.bottom - 8),
      Offset(r.left + 10 + segment, r.bottom - 8),
      paint,
    );

    canvas.drawLine(
      Offset(r.right - 8, r.bottom - 10 - segment),
      Offset(r.right - 8, r.bottom - 10),
      paint,
    );
    canvas.drawLine(
      Offset(r.right - 10 - segment, r.bottom - 8),
      Offset(r.right - 10, r.bottom - 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ChatScreen extends StatefulWidget {
  final bool showInitializationIndicator;
  final ValueChanged<bool>? onInitializationChanged;

  const ChatScreen({
    super.key,
    this.showInitializationIndicator = true,
    this.onInitializationChanged,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  static const String _appVersion = '1.2.14';
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
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OpenAIChatService _chatService = OpenAIChatService();
  final LocalStorageService _storageService = LocalStorageService.instance;
  final LicenseService _licenseService = LicenseService.instance;

  ChatSessionInfo? _activeSession;
  LicenseStatus? _licenseStatus;
  final List<ChatImageAttachment> _selectedImageAttachments = [];
  ImageGenerationOptions _generationOptions = ImageGenerationOptions.defaults();
  bool _retainReferenceImagesLocally = true;
  bool _isComposerDragTargetActive = false;
  bool _isSending = false;
  bool _isInitializing = true;
  final Set<String> _pollingTaskIds = <String>{};
  late final AnimationController _composerAuraController;

  bool get _hasPendingGenerationInActiveSession =>
      _messages.any(
        (message) =>
            message.role == Role.bot &&
            (message.isPending ||
                message.isInterrupted ||
                message.hasResolvableRemoteTask),
      );

  bool get _isGenerationLocked =>
      _isSending || _hasPendingGenerationInActiveSession;

  @override
  void initState() {
    super.initState();
    _composerAuraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    widget.onInitializationChanged?.call(true);
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
        _isInitializing = false;
      });
      widget.onInitializationChanged?.call(false);
      _resumePendingTasksForActiveSession();
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
      widget.onInitializationChanged?.call(false);
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
        heightFactor: 0.88,
        child: StatefulBuilder(
          builder: (context, setSheetState) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
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
                    '本应用当前会在本地保存：会话列表、聊天记录、AI 生图历史、授权状态。使用 AI 生成功能时，提示词和参考图会发送到云端服务处理。',
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await _openDownloadUrl(
                            'https://xiimax.top/privacy.html',
                          );
                        },
                        child: const Text('打开隐私政策'),
                      ),
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
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.15),
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.tonal(
                              onPressed: () =>
                                  Navigator.of(context).pop('settings'),
                              child: const Text('打开详细设置页'),
                            ),
                            FilledButton.tonal(
                              onPressed: () =>
                                  Navigator.of(context).pop('clear'),
                              child: const Text('清空全部本地数据'),
                            ),
                          ],
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
        _selectedImageAttachments.clear();
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
    _composerAuraController.dispose();
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

  void _resumePendingTasksForActiveSession() {
    final activeSession = _activeSession;
    if (activeSession == null) {
      return;
    }

    for (final message in _messages) {
      final taskId = message.remoteTaskId;
      if (message.id != null &&
          taskId != null &&
          taskId.isNotEmpty &&
          message.hasResolvableRemoteTask) {
        unawaited(
          _pollGenerationTask(
            sessionId: activeSession.id,
            messageId: message.id!,
            taskId: taskId,
            options: message.generationOptions ?? _generationOptions.normalized(),
          ),
        );
      }
    }
  }

  Future<void> _pollGenerationTask({
    required int sessionId,
    required int messageId,
    required String taskId,
    required ImageGenerationOptions options,
  }) async {
    if (!_pollingTaskIds.add(taskId)) {
      return;
    }

    try {
      for (var attempt = 0; attempt < 120; attempt++) {
        final response = await _chatService.fetchWorkerTask(
          taskId: taskId,
          options: options,
        );

        if (response.taskStatus == 'completed') {
          var licenseStatus = _licenseStatus ?? await _licenseService.initialize();
          if (!licenseStatus.isPremium) {
            licenseStatus = await _licenseService.consumeTrialUse();
          } else {
            licenseStatus = await _licenseService.refreshLicenseStatus();
          }

          final completedMessage = ChatMessage(
            id: messageId,
            text: response.text,
            role: Role.bot,
            createdAt: DateTime.now(),
            generatedImages: response.generatedImages,
            generationOptions: options,
            deliveryState: MessageDeliveryState.completed,
            remoteTaskId: taskId,
          );
          final savedMessage = await _storageService.updateMessage(
            messageId: messageId,
            message: completedMessage,
          );
          final sessions = await _storageService.loadSessions();
          final history = await _storageService.loadGeneratedImageHistory();
          if (!mounted) return;
          setState(() {
            _licenseStatus = licenseStatus;
            final index = _messages.indexWhere((message) => message.id == messageId);
            if (index >= 0 && savedMessage != null) {
              _messages[index] = savedMessage;
            }
            _sessions
              ..clear()
              ..addAll(sessions);
            _generatedImageHistory
              ..clear()
              ..addAll(history);
          });
          _scrollToBottom();
          return;
        }

        if (response.taskStatus == 'failed') {
          final failedMessage = ChatMessage(
            id: messageId,
            text: response.text,
            role: Role.bot,
            createdAt: DateTime.now(),
            generationOptions: options,
            deliveryState: MessageDeliveryState.failed,
            remoteTaskId: taskId,
          );
          final savedMessage = await _storageService.updateMessage(
            messageId: messageId,
            message: failedMessage,
          );
          if (!mounted) return;
          setState(() {
            final index = _messages.indexWhere((message) => message.id == messageId);
            if (index >= 0 && savedMessage != null) {
              _messages[index] = savedMessage;
            }
          });
          _scrollToBottom();
          return;
        }

        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } catch (_) {
      // Leave pending state in place; it can be resumed on next app open.
    } finally {
      _pollingTaskIds.remove(taskId);
    }
  }

  Future<void> _openSession(int sessionId, {bool recordSwitch = true}) async {
    if (_isGenerationLocked) {
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
        _selectedImageAttachments.clear();
      });
      _resumePendingTasksForActiveSession();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('切换会话失败：$e');
    }
  }

  Future<void> _createSession() async {
    if (_isGenerationLocked) {
      _showSnackBar('当前正在生成图片，请稍后再新建会话。');
      return;
    }

    try {
      final session = await _storageService.createSession();
      final sessions = await _storageService.loadSessions();
      final history = await _storageService.loadGeneratedImageHistory();
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
        _controller.clear();
        _selectedImageAttachments.clear();
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('新建会话失败：$e');
    }
  }

  Future<void> _renameSession(ChatSessionInfo session) async {
    if (_isGenerationLocked) {
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
    if (_isGenerationLocked) {
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

      if (!mounted) return;
      setState(() {
        _sessions
          ..clear()
          ..addAll(sessions);
        _generatedImageHistory
          ..clear()
          ..addAll(history);
        _activeSession = nextActiveSession;
        _messages
          ..clear()
          ..addAll(messages);
        _selectedImageAttachments.clear();
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
    if (_isGenerationLocked) {
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

  Widget _buildSessionPanel({
    required bool closeDrawerOnAction,
  }) {
    return _SessionSidebar(
      sessions: _sessions,
      activeSession: _activeSession,
      isBusy: _isGenerationLocked || _isInitializing,
      brandTitle: 'Xii_Raw Graph',
      brandBadge: '${_licenseStatus?.badgeLabel ?? '授权读取中'} · v$_appVersion',
      onOpenPrivacy: () async {
        if (closeDrawerOnAction) {
          Navigator.of(context).pop();
        }
        await _showPrivacyAndDataSheet();
      },
      onOpenPromptTemplates: () async {
        if (closeDrawerOnAction) {
          Navigator.of(context).pop();
        }
        await _openPromptTemplateLibrary();
      },
      onOpenActivation: () async {
        if (closeDrawerOnAction) {
          Navigator.of(context).pop();
        }
        await _showActivationDialog();
      },
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

  Future<void> _openPromptTemplateLibrary() async {
    final selectedPrompt = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const FractionallySizedBox(
        heightFactor: 0.9,
        child: _PromptTemplateLibrarySheet(),
      ),
    );

    if (selectedPrompt == null || selectedPrompt.isEmpty) {
      return;
    }

    _controller
      ..text = selectedPrompt
      ..selection = TextSelection.collapsed(offset: selectedPrompt.length);
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final attachments = <ChatImageAttachment>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          continue;
        }
        attachments.add(
          ChatImageAttachment(
            bytes: bytes,
            name: file.name,
            mimeType: _resolveMimeType(file.name),
          ),
        );
      }

      if (attachments.isEmpty) {
        _showSnackBar('暂时无法读取所选图片，请更换图片后重试。');
        return;
      }

      _appendSelectedImageAttachments(attachments);
    } catch (e) {
      _showSnackBar('选择图片失败：$e');
    }
  }

  Future<void> _handleComposerFileDrop(Iterable<dynamic> files) async {
    if (files.isEmpty) return;

    final attachments = <ChatImageAttachment>[];
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        final name = file.name.isEmpty ? 'drop_${attachments.length + 1}.png' : file.name;
        attachments.add(
          ChatImageAttachment(
            bytes: bytes,
            name: name,
            mimeType: _resolveMimeType(name),
          ),
        );
      } catch (_) {
        continue;
      }
    }

    if (attachments.isEmpty) {
      _showSnackBar('暂时无法读取拖拽的图片，请重试。');
      return;
    }

    _appendSelectedImageAttachments(attachments);
  }

  Future<ChatImageAttachment?> _buildReferenceAttachmentFromGeneratedImage(
    GeneratedImageAsset image,
  ) async {
    try {
      if (image.hasBytes) {
        return ChatImageAttachment(
          bytes: image.bytes!,
          name: image.fileName,
          mimeType: image.mimeType,
        );
      }

      if (image.hasUrl) {
        final response = await http.get(Uri.parse(image.imageUrl!));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        return ChatImageAttachment(
          bytes: response.bodyBytes,
          name: image.fileName,
          mimeType: image.mimeType,
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> _quoteGeneratedImageAsReference(
    GeneratedImageAsset image,
  ) async {
    final attachment = await _buildReferenceAttachmentFromGeneratedImage(image);
    if (attachment == null) {
      _showSnackBar('暂时无法引用这张图片，请稍后重试。');
      return;
    }

    _appendSelectedImageAttachments([attachment]);

    if (!mounted) return;
    _showSnackBar('已引用到对话，后续发送会将它作为参考图。');
  }

  void _appendSelectedImageAttachments(
    List<ChatImageAttachment> attachments,
  ) {
    if (attachments.isEmpty) return;

    final existingFingerprints = _selectedImageAttachments
        .map(_fingerprintAttachment)
        .toSet();
    final deduped = <ChatImageAttachment>[];
    var skippedCount = 0;

    for (final attachment in attachments) {
      final fingerprint = _fingerprintAttachment(attachment);
      if (existingFingerprints.add(fingerprint)) {
        deduped.add(attachment);
      } else {
        skippedCount++;
      }
    }

    if (deduped.isEmpty) {
      _showSnackBar('重复图片已自动忽略。');
      if (mounted) {
        setState(() {
          _isComposerDragTargetActive = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedImageAttachments.addAll(deduped);
      _isComposerDragTargetActive = false;
    });

    if (skippedCount > 0) {
      _showSnackBar('已自动去重，重复图片已忽略。');
    }
  }

  String _fingerprintAttachment(ChatImageAttachment attachment) {
    return sha1.convert(attachment.bytes).toString();
  }

  void _removeSelectedImageAt(int index) {
    setState(() {
      if (index >= 0 && index < _selectedImageAttachments.length) {
        _selectedImageAttachments.removeAt(index);
      }
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

  void _updateGenerationSize(String size) {
    setState(() {
      _generationOptions = _generationOptions.copyWith(size: size);
    });
  }

  void _updateGenerationQuality(String quality) {
    setState(() {
      _generationOptions = _generationOptions.copyWith(quality: quality);
    });
  }

  Future<void> _handleSend() async {
    final activeSession = _activeSession;
    var licenseStatus = _licenseStatus ?? await _licenseService.initialize();
    final text = _controller.text.trim();
    final imageAttachments = List<ChatImageAttachment>.from(
      _selectedImageAttachments,
    );
    final requestOptions = _generationOptions.normalized();
    if (activeSession == null || (text.isEmpty && imageAttachments.isEmpty)) {
      return;
    }

    final localSafetyMessage = _evaluateLocalSafety(
      text: text,
      hasReferenceImage: imageAttachments.isNotEmpty,
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
      localImages: imageAttachments.isEmpty
          ? const []
          : (_retainReferenceImagesLocally ? imageAttachments : const []),
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
        _selectedImageAttachments.clear();
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('保存用户消息失败：$e');
      return;
    }

    ChatMessage? savedPendingBotMessage;
    try {
      final pendingBotMessage = ChatMessage(
        text: '正在生成图片...',
        role: Role.bot,
        generationOptions: requestOptions,
        deliveryState: MessageDeliveryState.pending,
      );
      savedPendingBotMessage = await _storageService.saveMessage(
        sessionId: activeSession.id,
        message: pendingBotMessage,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(savedPendingBotMessage!);
      });
      _scrollToBottom();

      final response = await _chatService.sendMessage(
        prompt: text,
        options: requestOptions,
        imageAttachments: imageAttachments,
      );
      final taskId = response.taskId;
      if (taskId != null && taskId.isNotEmpty) {
        final pendingWithTask = ChatMessage(
          id: savedPendingBotMessage.id,
          text: savedPendingBotMessage.text,
          role: savedPendingBotMessage.role,
          createdAt: savedPendingBotMessage.createdAt,
          generatedImages: savedPendingBotMessage.generatedImages,
          localImages: savedPendingBotMessage.localImages,
          generationOptions: savedPendingBotMessage.generationOptions,
          deliveryState: savedPendingBotMessage.deliveryState,
          remoteTaskId: taskId,
        );
        final updatedPendingMessage = await _storageService.updateMessage(
          messageId: savedPendingBotMessage.id!,
          message: pendingWithTask,
        );
        if (updatedPendingMessage != null) {
          savedPendingBotMessage = updatedPendingMessage;
          if (mounted) {
            setState(() {
              final index = _messages.indexWhere(
                (message) => message.id == savedPendingBotMessage!.id,
              );
              if (index >= 0) {
                _messages[index] = savedPendingBotMessage!;
              }
            });
          }
        }
      }

      if (response.taskStatus != 'completed') {
        final pendingTaskId = savedPendingBotMessage.remoteTaskId;
        if (pendingTaskId != null) {
          unawaited(
            _pollGenerationTask(
              sessionId: activeSession.id,
              messageId: savedPendingBotMessage.id!,
              taskId: pendingTaskId,
              options: requestOptions,
            ),
          );
        }
        return;
      }

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
        deliveryState: MessageDeliveryState.completed,
        remoteTaskId: savedPendingBotMessage.remoteTaskId,
      );
      final savedBotMessage = await _storageService.updateMessage(
        messageId: savedPendingBotMessage.id!,
        message: botMessage,
      );
      final sessions = await _storageService.loadSessions();
      final history = await _storageService.loadGeneratedImageHistory();
      final refreshedActiveSession =
          _findSessionById(sessions, activeSession.id) ?? activeSession;

      if (!mounted) return;
      setState(() {
        _licenseStatus = licenseStatus;
        final index = _messages.indexWhere(
          (message) => message.id == savedPendingBotMessage!.id,
        );
        if (index >= 0 && savedBotMessage != null) {
          _messages[index] = savedBotMessage;
        }
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
        deliveryState: MessageDeliveryState.failed,
      );
      try {
        final savedErrorMessage = savedPendingBotMessage != null
            ? await _storageService.updateMessage(
                messageId: savedPendingBotMessage.id!,
                message: errorMessage,
              )
            : await _storageService.saveMessage(
                sessionId: activeSession.id,
                message: errorMessage,
              );
        final sessions = await _storageService.loadSessions();
        final refreshedActiveSession =
            _findSessionById(sessions, activeSession.id) ?? activeSession;

        if (!mounted) return;
        setState(() {
          _licenseStatus = licenseStatus;
          if (savedPendingBotMessage != null) {
            final index = _messages.indexWhere(
              (message) => message.id == savedPendingBotMessage!.id,
            );
            if (index >= 0 && savedErrorMessage != null) {
              _messages[index] = savedErrorMessage;
            }
          } else if (savedErrorMessage != null) {
            _messages.add(savedErrorMessage);
          }
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
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _handleOutpaintFromGeneratedImage(
    GeneratedImageAsset image,
  ) async {
    final activeSession = _activeSession;
    var licenseStatus = _licenseStatus ?? await _licenseService.initialize();
    if (activeSession == null) {
      return;
    }
    if (_isGenerationLocked) {
      _showSnackBar('当前正在生成图片，请稍后再编辑。');
      return;
    }
    if (!image.hasBytes && !image.hasUrl) {
      _showSnackBar('当前图片暂时无法用于扩图。');
      return;
    }

    if (!licenseStatus.canUseGeneration) {
      await _showActivationDialog();
      licenseStatus = _licenseStatus ?? await _licenseService.initialize();
      if (!licenseStatus.canUseGeneration) {
        return;
      }
    }

    final request = await showDialog<_OutpaintRequest>(
      context: context,
      builder: (dialogContext) => const _OutpaintConfigDialog(),
    );
    if (request == null) {
      return;
    }

    final localSafetyMessage = _evaluateLocalSafety(
      text: request.prompt,
      hasReferenceImage: true,
    );
    if (localSafetyMessage != null) {
      _showSnackBar(localSafetyMessage);
      return;
    }

    try {
      setState(() {
        _isSending = true;
      });

      final sourceInfo = await _loadGeneratedImageInfo(image);
      if (sourceInfo == null) {
        throw Exception('无法读取原图内容。');
      }

      final prepared = await _prepareOutpaintImages(
        sourceInfo: sourceInfo,
        leftRatio: request.leftRatio,
        rightRatio: request.rightRatio,
        topRatio: request.topRatio,
        bottomRatio: request.bottomRatio,
      );

      final response = await _chatService.editGeneratedImage(
        prompt: request.prompt,
        options: _generationOptions.normalized(),
        sourceImage: prepared.sourceImage,
        maskImage: prepared.maskImage,
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
        generationOptions: _generationOptions.normalized(),
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
      _showSnackBar('扩图已完成。');
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('扩图失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<_SourceImageInfo?> _loadGeneratedImageInfo(
    GeneratedImageAsset image,
  ) async {
    ChatImageAttachment? attachment;
    if (image.hasBytes) {
      attachment = ChatImageAttachment(
        bytes: image.bytes!,
        name: image.fileName,
        mimeType: image.mimeType,
      );
    } else if (image.hasUrl) {
      final response = await http.get(Uri.parse(image.imageUrl!));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('下载原图失败：HTTP ${response.statusCode}');
      }

      attachment = ChatImageAttachment(
        bytes: response.bodyBytes,
        name: image.fileName,
        mimeType: image.mimeType,
      );
    }

    if (attachment == null) {
      return null;
    }

    final codec = await ui.instantiateImageCodec(attachment.bytes);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;
    return _SourceImageInfo(
      attachment: attachment,
      width: uiImage.width,
      height: uiImage.height,
    );
  }

  Future<_PreparedEditImages> _prepareOutpaintImages({
    required _SourceImageInfo sourceInfo,
    required double leftRatio,
    required double rightRatio,
    required double topRatio,
    required double bottomRatio,
  }) async {
    final codec = await ui.instantiateImageCodec(sourceInfo.attachment.bytes);
    final frame = await codec.getNextFrame();
    final originalImage = frame.image;

    final sourceWidth = sourceInfo.width;
    final sourceHeight = sourceInfo.height;
    final leftExtra = leftRatio <= 0
        ? 0
        : (sourceWidth * leftRatio).round().clamp(64, 1536);
    final rightExtra = rightRatio <= 0
        ? 0
        : (sourceWidth * rightRatio).round().clamp(64, 1536);
    final topExtra = topRatio <= 0
        ? 0
        : (sourceHeight * topRatio).round().clamp(64, 1536);
    final bottomExtra = bottomRatio <= 0
        ? 0
        : (sourceHeight * bottomRatio).round().clamp(64, 1536);

    final canvasWidth = sourceWidth + leftExtra + rightExtra;
    final canvasHeight = sourceHeight + topExtra + bottomExtra;

    final offset = Offset(leftExtra.toDouble(), topExtra.toDouble());

    final sourceRecorder = ui.PictureRecorder();
    final sourceCanvas = Canvas(sourceRecorder);
    sourceCanvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
      Paint()..color = Colors.white,
    );
    sourceCanvas.drawImage(originalImage, offset, Paint());
    final sourcePicture = sourceRecorder.endRecording();
    final expandedImage =
        await sourcePicture.toImage(canvasWidth, canvasHeight);
    final expandedBytes = await expandedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    final maskRecorder = ui.PictureRecorder();
    final maskCanvas = Canvas(maskRecorder);
    maskCanvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
      Paint()..color = Colors.transparent,
    );
    maskCanvas.drawRect(
      Rect.fromLTWH(
        offset.dx,
        offset.dy,
        sourceWidth.toDouble(),
        sourceHeight.toDouble(),
      ),
      Paint()..color = Colors.white,
    );
    final maskPicture = maskRecorder.endRecording();
    final maskUiImage = await maskPicture.toImage(canvasWidth, canvasHeight);
    final maskBytes = await maskUiImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (expandedBytes == null || maskBytes == null) {
      throw Exception('生成扩图画布失败。');
    }

    return _PreparedEditImages(
      sourceImage: ChatImageAttachment(
        bytes: expandedBytes.buffer.asUint8List(),
        name: 'outpaint_source.png',
        mimeType: 'image/png',
      ),
      maskImage: ChatImageAttachment(
        bytes: maskBytes.buffer.asUint8List(),
        name: 'outpaint_mask.png',
        mimeType: 'image/png',
      ),
    );
  }

  Future<void> _handleInpaintFromGeneratedImage(
    GeneratedImageAsset image,
  ) async {
    final activeSession = _activeSession;
    var licenseStatus = _licenseStatus ?? await _licenseService.initialize();
    if (activeSession == null) {
      return;
    }
    if (_isGenerationLocked) {
      _showSnackBar('当前正在生成图片，请稍后再编辑。');
      return;
    }

    if (!licenseStatus.canUseGeneration) {
      await _showActivationDialog();
      licenseStatus = _licenseStatus ?? await _licenseService.initialize();
      if (!licenseStatus.canUseGeneration) {
        return;
      }
    }

    final request = await Navigator.of(context).push<_InpaintRequest>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (pageContext) => _InpaintEditorPage(
          image: image,
        ),
      ),
    );
    if (request == null) {
      return;
    }

    final localSafetyMessage = _evaluateLocalSafety(
      text: request.prompt,
      hasReferenceImage: true,
    );
    if (localSafetyMessage != null) {
      _showSnackBar(localSafetyMessage);
      return;
    }

    try {
      setState(() {
        _isSending = true;
      });

      final sourceInfo = await _loadGeneratedImageInfo(image);
      if (sourceInfo == null) {
        throw Exception('无法读取原图内容。');
      }

      final maskAttachment = await _buildInpaintMask(
        sourceInfo: sourceInfo,
        normalizedPoints: request.normalizedPoints,
        normalizedBrushRadius: request.normalizedBrushRadius,
      );

      final response = await _chatService.editGeneratedImage(
        prompt: request.prompt,
        options: _generationOptions.normalized(),
        sourceImage: sourceInfo.attachment,
        maskImage: maskAttachment,
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
        generationOptions: _generationOptions.normalized(),
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
      _showSnackBar('局部重绘已完成。');
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('局部重绘失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<ChatImageAttachment> _buildInpaintMask({
    required _SourceImageInfo sourceInfo,
    required List<Offset> normalizedPoints,
    required double normalizedBrushRadius,
  }) async {
    final width = sourceInfo.width;
    final height = sourceInfo.height;
    final brushRadius =
        (normalizedBrushRadius * width).clamp(8.0, width * 0.2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );
    final erasePaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = brushRadius * 2;
    if (normalizedPoints.length == 1) {
      final point = Offset(
        normalizedPoints.first.dx * width,
        normalizedPoints.first.dy * height,
      );
      canvas.drawCircle(point, brushRadius, erasePaint);
    } else if (normalizedPoints.length > 1) {
      final path = Path()
        ..moveTo(
          normalizedPoints.first.dx * width,
          normalizedPoints.first.dy * height,
        );
      for (final point in normalizedPoints.skip(1)) {
        path.lineTo(point.dx * width, point.dy * height);
      }
      canvas.drawPath(path, erasePaint);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw Exception('生成区域重绘蒙版失败。');
    }

    return ChatImageAttachment(
      bytes: bytes.buffer.asUint8List(),
      name: 'inpaint_mask.png',
      mimeType: 'image/png',
    );
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
    final width = MediaQuery.of(context).size.width;
    final isWideLayout = width >= 1120;
    final workspacePadding = width < 960 ? 10.0 : 14.0;
    final sidebarWidth = width >= 1360
        ? 340.0
        : width >= 1120
            ? 320.0
            : 0.0;

    return Scaffold(
      backgroundColor: _AppChromePalette.bg,
      drawer: isWideLayout
          ? null
          : Drawer(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              width: 296,
              child: SafeArea(
                minimum: EdgeInsets.fromLTRB(
                    workspacePadding, workspacePadding, 0, workspacePadding),
                child: _buildSessionPanel(closeDrawerOnAction: true),
              ),
            ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _AppChromePalette.appBackground,
        ),
        child: SafeArea(
          child: _isInitializing && widget.showInitializationIndicator
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
              : Stack(
                  children: [
                    Row(
                      children: [
                        if (isWideLayout)
                          SizedBox(
                            width: sidebarWidth,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                0,
                                workspacePadding,
                                0,
                                workspacePadding,
                              ),
                              child: _buildSessionPanel(
                                closeDrawerOnAction: false,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              isWideLayout ? 0 : workspacePadding,
                              workspacePadding,
                              workspacePadding,
                              workspacePadding,
                            ),
                            child: _buildChatWorkspace(
                              isWideLayout: isWideLayout,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: isWideLayout ? sidebarWidth : 0,
                      right: 0,
                      bottom: 0,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isWideLayout ? 16 : workspacePadding + 16,
                          0,
                          workspacePadding + 16,
                          24,
                        ),
                        child: _buildFloatingComposerOverlay(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildChatWorkspace({
    required bool isWideLayout,
  }) {
    final activeSession = _activeSession;
    final licenseStatus = _licenseStatus;
    final viewportSize = MediaQuery.of(context).size;
    final width = viewportSize.width;
    final contentMaxWidth = width < 980 ? double.infinity : 980.0;
    final composerReservedHeight = _measureComposerReservedHeight(
      width: width,
      licenseStatus: licenseStatus,
    );

    return Column(
      children: [
        if (!isWideLayout)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: '会话面板',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: '更多操作',
                  onSelected: (value) async {
                    switch (value) {
                      case 'new':
                        await _createSession();
                        break;
                      case 'history':
                        await _showGeneratedImageHistory();
                        break;
                      case 'templates':
                        await _openPromptTemplateLibrary();
                        break;
                      case 'privacy':
                        await _showPrivacyAndDataSheet();
                        break;
                      case 'clear':
                        await _clearMessages();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'new', child: Text('新建会话')),
                    PopupMenuItem(value: 'history', child: Text('AI 生图历史')),
                    PopupMenuItem(value: 'templates', child: Text('提示词模板库')),
                    PopupMenuItem(value: 'privacy', child: Text('数据与隐私')),
                    PopupMenuItem(value: 'clear', child: Text('清空聊天')),
                  ],
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              Column(
                children: [
                  if (activeSession != null)
                    SizedBox(
                      width: double.infinity,
                      child: _WorkspaceStatusStrip(
                        session: activeSession,
                        licenseStatus: licenseStatus,
                        onRefresh: _refreshLicenseStatus,
                        onContactAuthor: _showAuthorContactDialog,
                        onActivate: _showActivationDialog,
                      ),
                    ),
                  Expanded(
                    child: _messages.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                composerReservedHeight,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: contentMaxWidth,
                                    ),
                                    child: _EmptyWorkspaceHero(
                                      title: activeSession == null
                                          ? (licenseStatus?.isPremium ?? false)
                                              ? '欢迎使用 Xii_Raw Graph 高级版'
                                              : '欢迎使用 Xii_Raw Graph 试用版'
                                          : '欢迎回到「${activeSession.title}」',
                                      subtitle: licenseStatus?.summaryText ??
                                          '现在支持本地 SQLite 会话保存，以及 AI 生图历史回看。',
                                      sessionCount: _sessions.length,
                                      imageHistoryCount:
                                          _generatedImageHistory.length,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              composerReservedHeight,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: contentMaxWidth,
                                  ),
                                  child: AnimatedMessageBubble(
                                    key: ValueKey(
                                      message.id ?? message.createdAt,
                                    ),
                                    message: message,
                                    isNew: index == _messages.length - 1,
                                    onOutpaintImage:
                                        _handleOutpaintFromGeneratedImage,
                                    onInpaintImage:
                                        _handleInpaintFromGeneratedImage,
                                    onQuoteImage:
                                        _quoteGeneratedImageAsReference,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _measureComposerReservedHeight({
    required double width,
    required LicenseStatus? licenseStatus,
  }) {
    final hasAttachments = _selectedImageAttachments.isNotEmpty;
    final compact = width < 700;
    final showTrialFootnote = licenseStatus != null && !licenseStatus.isPremium;

    var height = compact ? 206.0 : 176.0;
    if (hasAttachments) {
      height += compact ? 116.0 : 96.0;
    }
    if (showTrialFootnote) {
      height += 28.0;
    }
    return height;
  }

  Widget _buildFloatingComposerOverlay() {
    final viewportWidth = MediaQuery.of(context).size.width;
    final licenseStatus = _licenseStatus;
    final composerMaxWidth = viewportWidth < 720
        ? double.infinity
        : viewportWidth < 980
            ? 760.0
            : 820.0;

    return DropTarget(
      onDragEntered: (_) {
        if (!mounted) return;
        setState(() {
          _isComposerDragTargetActive = true;
        });
      },
      onDragExited: (_) {
        if (!mounted) return;
        setState(() {
          _isComposerDragTargetActive = false;
        });
      },
      onDragDone: (detail) {
        _handleComposerFileDrop(detail.files);
      },
      child: AnimatedBuilder(
        animation: _composerAuraController,
        builder: (context, child) {
          const auraPalette = <Color>[
            Color(0xFF38BDF8),
            Color(0xFF60A5FA),
            Color(0xFF22C55E),
            Color(0xFFF59E0B),
            Color(0xFFFB7185),
            Color(0xFFA78BFA),
          ];
          final pulse = Curves.easeInOutSine.transform(
            _composerAuraController.value,
          );
          final colorPhase = _composerAuraController.value * auraPalette.length;
          final colorIndex = colorPhase.floor() % auraPalette.length;
          final nextColorIndex = (colorIndex + 1) % auraPalette.length;
          final colorMix = Curves.easeInOut.transform(colorPhase - colorIndex);
          final auraColor = Color.lerp(
            auraPalette[colorIndex],
            auraPalette[nextColorIndex],
            colorMix,
          )!;
          final borderColor = Color.lerp(
            _AppChromePalette.border,
            auraColor.withValues(alpha: 0.96),
            _isComposerDragTargetActive ? 1 : (0.34 + pulse * 0.38),
          )!;
          final borderWidth =
              _isComposerDragTargetActive ? 1.9 : 1.15 + pulse * 0.55;
          final auraAlpha =
              _isComposerDragTargetActive ? 0.34 : 0.18 + pulse * 0.20;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: composerMaxWidth),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  gradient: _AppChromePalette.panelGradient,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: borderColor,
                    width: borderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.34),
                      blurRadius: 34,
                      offset: const Offset(0, 22),
                    ),
                    BoxShadow(
                      color: auraColor.withValues(alpha: auraAlpha),
                      blurRadius: 40 + (pulse * 18),
                      spreadRadius: -4 + (pulse * 5),
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: auraColor.withValues(
                        alpha: _isComposerDragTargetActive
                            ? 0.18
                            : 0.08 + pulse * 0.10,
                      ),
                      blurRadius: 72 + (pulse * 24),
                      spreadRadius: -10 + (pulse * 6),
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildComposerField(licenseStatus),
            if (_selectedImageAttachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ComposerImagePreview(
                attachments: _selectedImageAttachments,
                onRemoveAt:
                    _isGenerationLocked ? null : _removeSelectedImageAt,
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 700;
                final controls = <Widget>[
                  _ComposerPill(
                    icon: _selectedImageAttachments.isEmpty
                        ? Icons.add_photo_alternate_outlined
                        : Icons.collections_rounded,
                    label: _selectedImageAttachments.isEmpty
                        ? '参考图'
                        : '参考图 ${_selectedImageAttachments.length}',
                    onTap: _isGenerationLocked || _activeSession == null
                        ? null
                        : _pickImage,
                  ),
                  _ComposerDropdownPill(
                    label: '尺寸',
                    value: _generationOptions.size,
                    items: ImageGenerationOptions.availableSizes,
                    displayBuilder: ImageGenerationOptions.displaySizeLabel,
                    onChanged:
                        _isGenerationLocked ? null : _updateGenerationSize,
                  ),
                  _ComposerDropdownPill(
                    label: '质量',
                    value: _generationOptions.quality,
                    items: ImageGenerationOptions.availableQualities,
                    displayBuilder: ImageGenerationOptions.displayQualityLabel,
                    onChanged:
                        _isGenerationLocked ? null : _updateGenerationQuality,
                  ),
                ];

                if (compact) {
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: controls,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildSendButton(),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < controls.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              controls[i],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildSendButton(),
                  ],
                );
              },
            ),
            if (licenseStatus != null && !licenseStatus.isPremium) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '目前\$0.08一张。',
                  style: TextStyle(
                    color: _AppChromePalette.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposerField(LicenseStatus? licenseStatus) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _AppChromePalette.borderSoft,
        ),
      ),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _handleSend(),
        enabled: !_isGenerationLocked &&
            !_isInitializing &&
            _activeSession != null &&
            (licenseStatus?.canUseGeneration ?? true),
        maxLines: null,
        decoration: InputDecoration(
          hintText: _selectedImageAttachments.isEmpty
              ? '描述你想要的图片，例如：电影感海边日落、暖色调、超细节等...'
              : '输入描述，结合参考图一起生成...',
          hintStyle: TextStyle(
            color: _AppChromePalette.textSoft,
          ),
          prefixIcon: Icon(
            Icons.mode_comment_outlined,
            color: _AppChromePalette.accent,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isGenerationLocked ? 48 : 80,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isGenerationLocked
              ? [const Color(0xFF334155), const Color(0xFF475569)]
              : const [Color(0xFF38BDF8), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isGenerationLocked
              ? const Color(0xFF475569)
              : const Color(0xFF7DD3FC).withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color:
                (_isGenerationLocked ? const Color(0xFF334155) : const Color(0xFF38BDF8))
                    .withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _isGenerationLocked || _activeSession == null ? null : _handleSend,
          child: Center(
            child: _isGenerationLocked
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(
            color: _AppChromePalette.border,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF10213D),
                  Color(0xFF172554),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: _AppChromePalette.accent,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
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
                    color: _AppChromePalette.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '消息 ${session.messageCount} 条',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AppChromePalette.textMuted,
                    fontSize: 10.5,
                  ),
                ),
                Text(
                  '最近活跃 ${_formatTime(session.sortTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AppChromePalette.textSoft,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onRefresh,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('刷新'),
            ),
            FilledButton.tonal(
              onPressed: onContactAuthor,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                shape: const StadiumBorder(),
              ),
              child: const Text('联系作者'),
            ),
            FilledButton.tonal(
              onPressed: onActivate,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                shape: const StadiumBorder(),
              ),
              child: const Text('授权中心'),
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
  final String brandTitle;
  final String brandBadge;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenPromptTemplates;
  final VoidCallback onOpenActivation;
  final ValueChanged<ChatSessionInfo> onSelectSession;
  final ValueChanged<ChatSessionInfo> onRenameSession;
  final ValueChanged<ChatSessionInfo> onDeleteSession;
  final VoidCallback onCreateSession;
  final VoidCallback onOpenImageHistory;

  const _SessionSidebar({
    required this.sessions,
    required this.activeSession,
    required this.isBusy,
    required this.brandTitle,
    required this.brandBadge,
    required this.onOpenPrivacy,
    required this.onOpenPromptTemplates,
    required this.onOpenActivation,
    required this.onSelectSession,
    required this.onRenameSession,
    required this.onDeleteSession,
    required this.onCreateSession,
    required this.onOpenImageHistory,
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF091120),
            Color(0xFF0E1A31),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: _AppChromePalette.border,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF111827).withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          'assets/branding/app_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            brandTitle,
                            style: TextStyle(
                              color: _AppChromePalette.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            activeSession?.title ?? '准备开始新的图像创作',
                            style: TextStyle(
                              color: _AppChromePalette.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _AppChromePalette.border,
                              ),
                            ),
                            child: Text(
                              brandBadge,
                              style: TextStyle(
                                color: _AppChromePalette.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SidebarNavButton(
                  icon: Icons.add_circle_outline_rounded,
                  label: '新对话',
                  highlighted: true,
                  onPressed: isBusy ? null : onCreateSession,
                ),
                const SizedBox(height: 6),
                _SidebarNavButton(
                  icon: Icons.photo_library_outlined,
                  label: '生成记录',
                  onPressed: onOpenImageHistory,
                ),
                const SizedBox(height: 6),
                _SidebarNavButton(
                  icon: Icons.library_books_outlined,
                  label: '提示词模板库',
                  onPressed: onOpenPromptTemplates,
                ),
                const SizedBox(height: 6),
                _SidebarNavButton(
                  icon: Icons.privacy_tip_outlined,
                  label: '数据与隐私',
                  onPressed: onOpenPrivacy,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '历史对话',
                    style: TextStyle(
                      color: _AppChromePalette.textSoft,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: sessions.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              child: Text(
                                '还没有会话，点击上方“新建对话”开始第一条创作。',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _AppChromePalette.textMuted,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
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
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      gradient: selected
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFF10213D),
                                                Color(0xFF172554),
                                              ],
                                            )
                                          : const LinearGradient(
                                              colors: [
                                                Color(0xFF0F172A),
                                                Color(0xFF111827),
                                              ],
                                            ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: selected
                                            ? _AppChromePalette.accent
                                            : _AppChromePalette.borderSoft,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: selected ? 0.18 : 0.10,
                                          ),
                                          blurRadius: 18,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                      ? Colors.white
                                                      : _AppChromePalette.text,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (selected)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    999,
                                                  ),
                                                ),
                                                child: const Text(
                                                  '当前',
                                                  style: TextStyle(
                                                    color: Color(0xFFD7EBFF),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            PopupMenuButton<String>(
                                              tooltip: '会话操作',
                                              padding: EdgeInsets.zero,
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
                                                    ? Colors.white
                                                    : _AppChromePalette.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '消息 ${session.messageCount} 条',
                                          style: TextStyle(
                                            color: selected
                                                ? const Color(0xFFD7EBFF)
                                                : _AppChromePalette.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '最近使用 ${_formatTime(session.sortTime)}',
                                          style: TextStyle(
                                            color: selected
                                                ? const Color(0xFFB8D9FF)
                                                : _AppChromePalette.textSoft,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool highlighted;

  const _SidebarNavButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: highlighted
              ? const LinearGradient(
                  colors: [
                    Color(0xFF10213D),
                    Color(0xFF172554),
                  ],
                )
              : null,
          color: highlighted ? null : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? _AppChromePalette.accent
                : _AppChromePalette.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: highlighted
                  ? Colors.white
                  : _AppChromePalette.text,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: highlighted
                      ? Colors.white
                      : _AppChromePalette.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 164),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _AppChromePalette.borderSoft,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF10213D),
                  Color(0xFF172554),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 15,
              color: _AppChromePalette.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AppChromePalette.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AppChromePalette.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkspaceHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final int sessionCount;
  final int imageHistoryCount;

  const _EmptyWorkspaceHero({
    required this.title,
    required this.subtitle,
    required this.sessionCount,
    required this.imageHistoryCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF111C34),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _AppChromePalette.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF10213D),
                  Color(0xFF172554),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 28,
              color: _AppChromePalette.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.45,
              color: _AppChromePalette.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13.5,
              color: _AppChromePalette.textMuted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              const _MetricBadge(
                icon: Icons.bolt_rounded,
                label: '快速出图',
                value: '企业级工作流',
              ),
              _MetricBadge(
                icon: Icons.layers_rounded,
                label: '会话能力',
                value: '$sessionCount 个本地会话',
              ),
              _MetricBadge(
                icon: Icons.photo_library_rounded,
                label: '历史记录',
                value: '$imageHistoryCount 张图片',
              ),
            ],
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
        gradient: _AppChromePalette.panelGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: _AppChromePalette.border),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 52,
            height: 5,
            decoration: BoxDecoration(
              color: _AppChromePalette.border.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: _AppChromePalette.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI 生图历史',
                    style: TextStyle(
                      color: _AppChromePalette.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                Text(
                  '${entries.length} 张',
                  style: TextStyle(
                    color: _AppChromePalette.textMuted,
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
                        color: _AppChromePalette.textMuted,
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
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0F172A),
                              Color(0xFF111827),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _AppChromePalette.borderSoft,
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
                                      color: _AppChromePalette.text,
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
                                      color: _AppChromePalette.textMuted,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${ImageGenerationOptions.displaySizeLabel(entry.size ?? 'auto')} · ${ImageGenerationOptions.displayQualityLabel(entry.quality ?? 'auto')} · ${_formatTime(entry.createdAt)}',
                                    style: TextStyle(
                                      color: _AppChromePalette.textSoft,
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


class AnimatedMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isNew;
  final ValueChanged<GeneratedImageAsset> onOutpaintImage;
  final ValueChanged<GeneratedImageAsset> onInpaintImage;
  final ValueChanged<GeneratedImageAsset> onQuoteImage;

  const AnimatedMessageBubble({
    super.key,
    required this.message,
    this.isNew = false,
    required this.onOutpaintImage,
    required this.onInpaintImage,
    required this.onQuoteImage,
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
        child: ChatBubble(
          message: widget.message,
          onOutpaintImage: widget.onOutpaintImage,
          onInpaintImage: widget.onInpaintImage,
          onQuoteImage: widget.onQuoteImage,
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<GeneratedImageAsset> onOutpaintImage;
  final ValueChanged<GeneratedImageAsset> onInpaintImage;
  final ValueChanged<GeneratedImageAsset> onQuoteImage;

  const ChatBubble({
    super.key,
    required this.message,
    required this.onOutpaintImage,
    required this.onInpaintImage,
    required this.onQuoteImage,
  });

  void _copyMessageText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(content: Text('文字已复制')),
    );
  }

  void _showImagePreview(
    BuildContext context,
    Widget image, {
    GeneratedImageAsset? editableImage,
  }) {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: '关闭图片预览',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ImagePreviewDialog(
          image: image,
          onQuote: editableImage == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  onQuoteImage(editableImage);
                },
          onOutpaint: editableImage == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  onOutpaintImage(editableImage);
                },
          onInpaint: editableImage == null
              ? null
              : () async {
                  final shouldOpen = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('区域重绘'),
                      content: const Text(
                        '该功能仍在优化中，部分大图可能出现卡顿。是否继续进入区域重绘？',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text('取消'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text('继续'),
                        ),
                      ],
                    ),
                  );
                  if (shouldOpen != true) {
                    return;
                  }
                  Navigator.of(context).pop();
                  onInpaintImage(editableImage);
                },
        );
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
        height: 180,
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
        height: 180,
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
    if (message.shouldShowGenerationPlaceholder) {
      return _GeminiGenerationPlaceholder(
        sizeValue: message.generationOptions?.size ?? 'auto',
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isUser = message.role == Role.user;
    final bubbleColor = isUser
        ? const Color(0xFF17305C)
        : Colors.white.withValues(alpha: 0.045);
    final textColor = isUser ? Colors.white : _AppChromePalette.text;
    final avatar = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                colors: [
                  Color(0xFF1D4ED8),
                  Color(0xFF38BDF8),
                ],
              )
            : const LinearGradient(
                colors: [
                  Color(0xFF111827),
                  Color(0xFF1E293B),
                ],
              ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        color: Colors.white,
        size: 18,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: isUser
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (message.text.isNotEmpty)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: screenWidth < 720
                                  ? screenWidth * 0.8
                                  : screenWidth < 980
                                      ? 460
                                      : 520,
                            ),
                            child: _CopyableMessageContent(
                              text: message.text,
                              bubbleColor: bubbleColor,
                              textColor: textColor,
                              isUser: true,
                              onCopy: () =>
                                  _copyMessageText(context, message.text),
                            ),
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
                              editableImage: image,
                            ),
                            onQuote: () => onQuoteImage(image),
                            child: _buildGeneratedImageWidget(
                              image,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ImageDownloadAction(
                            image: image,
                            alignment: Alignment.centerRight,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  avatar,
                ],
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 助手',
                            style: TextStyle(
                              color: _AppChromePalette.textMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (message.isInterrupted || message.isFailed) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: message.isFailed
                                    ? const Color(0xFFFEF2F2)
                                    : const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: message.isFailed
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFFFCD34D),
                                ),
                              ),
                              child: Text(
                                message.isFailed
                                    ? message.text
                                    : '上次图片生成在应用关闭前未完成，任务已中断，请重新发起。',
                                style: TextStyle(
                                  color: message.isFailed
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF9A3412),
                                  height: 1.6,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ] else if (message.text.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    screenWidth < 980 ? screenWidth * 0.92 : 860,
                              ),
                              child: _CopyableMessageContent(
                                text: message.text,
                                bubbleColor: bubbleColor,
                                textColor: textColor,
                                isUser: false,
                                onCopy: () =>
                                    _copyMessageText(context, message.text),
                              ),
                            ),
                          ],
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
                                editableImage: image,
                              ),
                              onQuote: () => onQuoteImage(image),
                              child: _buildGeneratedImageWidget(
                                image,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _ImageDownloadAction(
                              image: image,
                              alignment: Alignment.centerLeft,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CopyableMessageContent extends StatefulWidget {
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
  State<_CopyableMessageContent> createState() => _CopyableMessageContentState();
}

class _CopyableMessageContentState extends State<_CopyableMessageContent> {
  bool _showCopyAction = false;

  @override
  Widget build(BuildContext context) {
    final actionAlignment =
        widget.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final textAlign = widget.isUser ? TextAlign.right : TextAlign.left;
    final textColor = widget.isUser
        ? Theme.of(context).colorScheme.onSurface
        : widget.textColor;
    final textHeight = widget.isUser ? 1.52 : 1.78;

    return MouseRegion(
      onEnter: (_) {
        if (!_showCopyAction) {
          setState(() {
            _showCopyAction = true;
          });
        }
      },
      onExit: (_) {
        if (_showCopyAction) {
          setState(() {
            _showCopyAction = false;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment:
              widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: BoxDecoration(
                color: widget.bubbleColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: widget.isUser
                      ? const Color(0xFF60A5FA).withValues(alpha: 0.26)
                      : _AppChromePalette.borderSoft,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 24),
                child: SelectableText(
                  widget.text,
                  textAlign: textAlign,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: textColor,
                    height: textHeight,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              child: Align(
                alignment: actionAlignment,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: _showCopyAction ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_showCopyAction,
                    child: TextButton.icon(
                      onPressed: widget.onCopy,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        Icons.content_copy_rounded,
                        size: 15,
                        color: _AppChromePalette.textMuted,
                      ),
                      label: Text(
                        '复制',
                        style: TextStyle(
                          color: _AppChromePalette.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
          decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _AppChromePalette.borderSoft,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                            _AppChromePalette.accent,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.download_rounded,
                        color: _AppChromePalette.accent,
                        size: 18,
                      ),
                label: Text(
                  _isDownloading ? '正在下载...' : '下载图片',
                  style: TextStyle(
                    color: _AppChromePalette.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              if (_isDownloading && progress != null) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.progress,
                      minHeight: 6,
                      backgroundColor:
                          _AppChromePalette.panelElevated.withValues(alpha: 0.7),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _AppChromePalette.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    '${progress.message} · ${progress.progressLabel}',
                    style: TextStyle(
                      color: _AppChromePalette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
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
  final List<ChatImageAttachment> attachments;
  final ValueChanged<int>? onRemoveAt;

  const _ComposerImagePreview({
    required this.attachments,
    this.onRemoveAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _AppChromePalette.borderSoft,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '已选择参考图（${attachments.length} 张）',
                  style: TextStyle(
                    color: _AppChromePalette.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: attachments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final attachment = attachments[index];
                      return SizedBox(
                        width: 72,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => showGeneralDialog<void>(
                                        context: context,
                                        barrierDismissible: true,
                                        barrierLabel: '预览参考图',
                                        barrierColor: Colors.black87,
                                        pageBuilder: (context, _, __) =>
                                            _ImagePreviewDialog(
                                          image: Image.memory(
                                            attachment.bytes,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high,
                                          ),
                                        ),
                                      ),
                                      child: Image.memory(
                                        attachment.bytes,
                                        width: 72,
                                        height: 54,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Material(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(999),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: onRemoveAt == null
                                          ? null
                                          : () => onRemoveAt!(index),
                                      child: const Padding(
                                        padding: EdgeInsets.all(3),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 11,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              attachment.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _AppChromePalette.textMuted,
                                fontSize: 10.5,
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
          ),
        ],
      ),
    );
  }
}

class _ComposerPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ComposerPill({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.025),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _AppChromePalette.borderSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled
                    ? _AppChromePalette.accent
                    : _AppChromePalette.textSoft.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? _AppChromePalette.text
                      : _AppChromePalette.textSoft.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerDropdownPill extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final String Function(String value) displayBuilder;
  final ValueChanged<String>? onChanged;

  const _ComposerDropdownPill({
    required this.label,
    required this.value,
    required this.items,
    required this.displayBuilder,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _AppChromePalette.borderSoft,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(18),
          dropdownColor: _AppChromePalette.panelElevated,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _AppChromePalette.textMuted,
          ),
          style: TextStyle(
            color: _AppChromePalette.text,
            fontWeight: FontWeight.w600,
          ),
          selectedItemBuilder: (context) => items
              .map(
                (item) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$label · ${displayBuilder(item)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged == null
              ? null
              : (nextValue) {
                  if (nextValue != null) {
                    onChanged!(nextValue);
                  }
                },
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    '$label · ${displayBuilder(item)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ChatImageFrame extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onQuote;

  const _ChatImageFrame({
    required this.child,
    this.onTap,
    this.onQuote,
  });

  @override
  Widget build(BuildContext context) {
    final imageFrame = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 220,
              maxWidth: 260,
            ),
            child: child,
          ),
          if (onTap != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onQuote != null)
                    Material(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        onTap: onQuote,
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.reply_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  if (onQuote != null) const SizedBox(width: 8),
                  IgnorePointer(
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
                ],
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
          border: Border.all(
            color: _AppChromePalette.borderSoft,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 22,
              offset: const Offset(0, 12),
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
  final VoidCallback? onOutpaint;
  final VoidCallback? onInpaint;
  final VoidCallback? onQuote;

  const _ImagePreviewDialog({
    required this.image,
    this.onOutpaint,
    this.onInpaint,
    this.onQuote,
  });

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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onQuote != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: TextButton.icon(
                        onPressed: onQuote,
                        icon: const Icon(
                          Icons.reply_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          '引用',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  if (onQuote != null) const SizedBox(width: 10),
                  if (onInpaint != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: TextButton.icon(
                        onPressed: onInpaint,
                        icon: const Icon(
                          Icons.brush_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          '区域重绘',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  if (onInpaint != null) const SizedBox(width: 10),
                  if (onOutpaint != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: TextButton.icon(
                        onPressed: onOutpaint,
                        icon: const Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          '扩图',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  if (onOutpaint != null) const SizedBox(width: 10),
                  DecoratedBox(
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
                ],
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

class _OutpaintConfigDialog extends StatefulWidget {
  const _OutpaintConfigDialog();

  @override
  State<_OutpaintConfigDialog> createState() => _OutpaintConfigDialogState();
}

class _OutpaintConfigDialogState extends State<_OutpaintConfigDialog> {
  final TextEditingController _promptController = TextEditingController();
  double _leftRatio = 0;
  double _rightRatio = 0.35;
  double _topRatio = 0;
  double _bottomRatio = 0;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.72;
    const previewBaseWidth = 280.0;
    const previewBaseHeight = 180.0;
    final previewLeft = previewBaseWidth * _leftRatio;
    final previewRight = previewBaseWidth * _rightRatio;
    final previewTop = previewBaseHeight * _topRatio;
    final previewBottom = previewBaseHeight * _bottomRatio;
    return AlertDialog(
      title: const Text('扩图'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _promptController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '扩图描述',
                    hintText: '例如：向右扩展窗外风景，并在顶部补一些云层',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '四边扩展比例',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: previewBaseWidth + previewLeft + previewRight,
                    height: previewBaseHeight + previewTop + previewBottom,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.18),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFFE0E7FF),
                            ),
                          ),
                        ),
                        Positioned(
                          left: previewLeft,
                          top: previewTop,
                          width: previewBaseWidth,
                          height: previewBaseHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF2563EB),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                '原图区域',
                                style: TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildRatioSlider(
                  context,
                  label: '左侧',
                  value: _leftRatio,
                  onChanged: (value) => setState(() => _leftRatio = value),
                ),
                _buildRatioSlider(
                  context,
                  label: '右侧',
                  value: _rightRatio,
                  onChanged: (value) => setState(() => _rightRatio = value),
                ),
                _buildRatioSlider(
                  context,
                  label: '上方',
                  value: _topRatio,
                  onChanged: (value) => setState(() => _topRatio = value),
                ),
                _buildRatioSlider(
                  context,
                  label: '下方',
                  value: _bottomRatio,
                  onChanged: (value) => setState(() => _bottomRatio = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final prompt = _promptController.text.trim();
            if (prompt.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              _OutpaintRequest(
                prompt: prompt,
                leftRatio: _leftRatio,
                rightRatio: _rightRatio,
                topRatio: _topRatio,
                bottomRatio: _bottomRatio,
              ),
            );
          },
          child: const Text('开始扩图'),
        ),
      ],
    );
  }

  Widget _buildRatioSlider(
    BuildContext context, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ${(value * 100).round()}%',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Slider(
            value: value,
            min: 0,
            max: 0.7,
            divisions: 14,
            label: '${(value * 100).round()}%',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _InpaintEditorPage extends StatefulWidget {
  final GeneratedImageAsset image;

  const _InpaintEditorPage({
    required this.image,
  });

  @override
  State<_InpaintEditorPage> createState() => _InpaintEditorPageState();
}

class _InpaintEditorPageState extends State<_InpaintEditorPage> {
  final TextEditingController _promptController = TextEditingController();
  final List<Offset> _strokePoints = [];
  Size? _previewSize;
  Rect? _imageViewportRect;
  bool _isDrawing = false;
  double _brushRadius = 18;
  Offset? _lastStrokePoint;
  Offset? _hoverPoint;
  late final Future<_PreviewThumbnailData?> _previewBytesFuture;

  @override
  void initState() {
    super.initState();
    _previewBytesFuture = _preparePreviewBytes();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<_PreviewThumbnailData?> _preparePreviewBytes() async {
    try {
      Uint8List sourceBytes;
      if (widget.image.hasBytes) {
        sourceBytes = widget.image.bytes!;
      } else if (widget.image.hasUrl) {
        final response = await http.get(Uri.parse(widget.image.imageUrl!));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        sourceBytes = response.bodyBytes;
      } else {
        return null;
      }

      return compute(
        _buildPreviewThumbnailBytes,
        _PreviewThumbnailJob(
          bytes: sourceBytes,
          targetWidth: 960,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  void _appendStrokePoint(Offset localPosition, Size size, Rect viewportRect) {
    final current = Offset(
      localPosition.dx.clamp(viewportRect.left, viewportRect.right),
      localPosition.dy.clamp(viewportRect.top, viewportRect.bottom),
    );
    final last = _lastStrokePoint;
    if (last != null && (current - last).distance < 4.0) {
      return;
    }
    setState(() {
      _strokePoints.add(current);
      _lastStrokePoint = current;
      _hoverPoint = current;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('区域重绘'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final editor = SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  _buildInpaintPreviewPanel(context),
                  const SizedBox(height: 20),
                  _buildInpaintControlsPanel(context),
                ],
              ),
            );

            if (!isWide) {
              return editor;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildInpaintPreviewPanel(context),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _buildInpaintControlsPanel(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInpaintPreviewPanel(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '涂抹需要重绘的区域',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '先在图上涂抹，再输入一句自然语言描述，提交后仅修改你选中的部分。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final imageWidth = constraints.maxWidth;
                final imageHeight = (imageWidth * 0.72).clamp(320.0, 600.0);
                _previewSize = Size(imageWidth, imageHeight);
                return FutureBuilder<_PreviewThumbnailData?>(
                  future: _previewBytesFuture,
                  builder: (context, snapshot) {
                    final previewData = snapshot.data;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: imageWidth,
                        height: imageHeight,
                        child: snapshot.connectionState != ConnectionState.done
                            ? Container(
                                color: Colors.black.withValues(alpha: 0.04),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '正在加载重绘预览…',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      ),
                                    ],
                                  ),
                                )
                            : previewData == null
                                ? Container(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Text(
                                      '预览加载失败，请关闭后重试。',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                : MouseRegion(
                                    onHover: (event) {
                                      final viewportRect = _imageViewportRect ??
                                          Rect.fromLTWH(
                                            0,
                                            0,
                                            imageWidth,
                                            imageHeight,
                                          );
                                      setState(() {
                                        _hoverPoint = Offset(
                                          event.localPosition.dx.clamp(
                                            viewportRect.left,
                                            viewportRect.right,
                                          ),
                                          event.localPosition.dy.clamp(
                                            viewportRect.top,
                                            viewportRect.bottom,
                                          ),
                                        );
                                      });
                                    },
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanStart: (details) {
                                        final size = Size(imageWidth, imageHeight);
                                        final viewportRect =
                                            _imageViewportRect ??
                                                Rect.fromLTWH(
                                                  0,
                                                  0,
                                                  imageWidth,
                                                  imageHeight,
                                                );
                                        setState(() {
                                          _isDrawing = true;
                                          _hoverPoint = Offset(
                                            details.localPosition.dx.clamp(
                                              viewportRect.left,
                                              viewportRect.right,
                                            ),
                                            details.localPosition.dy.clamp(
                                              viewportRect.top,
                                              viewportRect.bottom,
                                            ),
                                          );
                                        });
                                        _appendStrokePoint(
                                          details.localPosition,
                                          size,
                                          viewportRect,
                                        );
                                      },
                                      onPanUpdate: (details) {
                                        final size = Size(imageWidth, imageHeight);
                                        final viewportRect =
                                            _imageViewportRect ??
                                                Rect.fromLTWH(
                                                  0,
                                                  0,
                                                  imageWidth,
                                                  imageHeight,
                                                );
                                        setState(() {
                                          _hoverPoint = Offset(
                                            details.localPosition.dx.clamp(
                                              viewportRect.left,
                                              viewportRect.right,
                                            ),
                                            details.localPosition.dy.clamp(
                                              viewportRect.top,
                                              viewportRect.bottom,
                                            ),
                                          );
                                        });
                                        _appendStrokePoint(
                                          details.localPosition,
                                          size,
                                          viewportRect,
                                        );
                                      },
                                      onPanEnd: (_) {
                                        setState(() {
                                          _isDrawing = false;
                                          _lastStrokePoint = null;
                                        });
                                      },
                                      onPanCancel: () {
                                        setState(() {
                                          _isDrawing = false;
                                          _lastStrokePoint = null;
                                        });
                                      },
                                      child: RepaintBoundary(
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: LayoutBuilder(
                                                builder: (context, inner) {
                                                  final containerWidth =
                                                      inner.maxWidth;
                                                  final containerHeight =
                                                      inner.maxHeight;
                                                  final imageAspect =
                                                      previewData.aspectRatio;
                                                  double fittedWidth =
                                                      containerWidth;
                                                  double fittedHeight =
                                                      fittedWidth / imageAspect;
                                                  if (fittedHeight >
                                                      containerHeight) {
                                                    fittedHeight =
                                                        containerHeight;
                                                    fittedWidth =
                                                        fittedHeight *
                                                            imageAspect;
                                                  }
                                                  final left =
                                                      (containerWidth -
                                                              fittedWidth) /
                                                          2;
                                                  final top =
                                                      (containerHeight -
                                                              fittedHeight) /
                                                          2;
                                                  _imageViewportRect =
                                                      Rect.fromLTWH(
                                                        left,
                                                        top,
                                                        fittedWidth,
                                                        fittedHeight,
                                                      );
                                                  return Image.memory(
                                                    previewData.bytes,
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        FilterQuality.low,
                                                    gaplessPlayback: true,
                                                  );
                                                },
                                              ),
                                            ),
                                            if (_strokePoints.isNotEmpty)
                                              Positioned.fill(
                                                child: RepaintBoundary(
                                                  child: CustomPaint(
                                                    painter:
                                                        _BrushSelectionPainter(
                                                      points: _strokePoints,
                                                      brushRadius: _brushRadius,
                                                      isActive: _isDrawing,
                                                      imageViewportRect:
                                                          _imageViewportRect,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Positioned.fill(
                                              child: IgnorePointer(
                                                child: CustomPaint(
                                                  painter: _BrushCursorPainter(
                                                    center: _hoverPoint ??
                                                        Offset(
                                                          (_imageViewportRect
                                                                      ?.center
                                                                      .dx ??
                                                                  imageWidth /
                                                                      2),
                                                          (_imageViewportRect
                                                                      ?.center
                                                                      .dy ??
                                                                  imageHeight /
                                                                      2),
                                                        ),
                                                    brushRadius: _brushRadius,
                                                    isActive: _isDrawing,
                                                    imageViewportRect:
                                                        _imageViewportRect,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInpaintControlsPanel(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _promptController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '重绘描述',
                hintText: '例如：把这个区域改成金色浮雕徽章，保持其余区域不变',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '笔刷大小 ${(2 * _brushRadius).round()} px',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            Slider(
              value: _brushRadius,
              min: 8,
              max: 40,
              divisions: 8,
              label: '${(2 * _brushRadius).round()} px',
              onChanged: (value) {
                setState(() {
                  _brushRadius = value;
                });
              },
            ),
            const SizedBox(height: 6),
            Text(
              '提示：你涂抹到的区域会被重新生成，其余部分尽量保持不变。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _strokePoints.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _strokePoints.clear();
                          });
                        },
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('清空涂抹'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _strokePoints.isEmpty
                      ? null
                      : () {
                          final prompt = _promptController.text.trim();
                          if (prompt.isEmpty) {
                            return;
                          }
                          final size = _previewSize;
                          if (size == null || _strokePoints.isEmpty) {
                            return;
                          }
                          final viewportRect = _imageViewportRect ??
                              Rect.fromLTWH(0, 0, size.width, size.height);
                          final normalizedPoints = _strokePoints
                              .map(
                                (point) => Offset(
                                  ((point.dx - viewportRect.left) /
                                          viewportRect.width)
                                      .clamp(0.0, 1.0),
                                  ((point.dy - viewportRect.top) /
                                          viewportRect.height)
                                      .clamp(0.0, 1.0),
                                ),
                              )
                              .toList(growable: false);
                          Navigator.of(context).pop(
                            _InpaintRequest(
                              prompt: prompt,
                              normalizedPoints: normalizedPoints,
                              normalizedBrushRadius:
                                  (_brushRadius / viewportRect.width)
                                      .clamp(0.0, 0.5),
                            ),
                          );
                        },
                  child: const Text('开始重绘'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GeminiGenerationPlaceholder extends StatefulWidget {
  final String sizeValue;

  const _GeminiGenerationPlaceholder({
    required this.sizeValue,
  });

  @override
  State<_GeminiGenerationPlaceholder> createState() =>
      _GeminiGenerationPlaceholderState();
}

class _GeminiGenerationPlaceholderState
    extends State<_GeminiGenerationPlaceholder>
    with SingleTickerProviderStateMixin {
  static const TextStyle _stubTextStyle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
  );

  late final AnimationController _controller;
  late final double _detailStubWidth;
  late final double _referenceStubWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _detailStubWidth = _measureStubWidth('图像细节渲染中');
    _referenceStubWidth = _measureStubWidth('保持参考图主体特征');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageAspectRatio = _resolvePlaceholderAspectRatio(widget.sizeValue);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF10213D),
                  Color(0xFF172554),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 助手',
                    style: TextStyle(
                      color: _AppChromePalette.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildPulseDot(const Color(0xFF5B8CFF), 0),
                      const SizedBox(width: 6),
                      _buildPulseDot(const Color(0xFF8B5CF6), 0.16),
                      const SizedBox(width: 6),
                      _buildPulseDot(const Color(0xFF06B6D4), 0.32),
                      const SizedBox(width: 12),
                      Text(
                        '正在构图并生成图像…',
                        style: TextStyle(
                          color: _AppChromePalette.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RepaintBoundary(
                    child: _buildShimmerTextStub(
                      _detailStubWidth,
                      delay: 0.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RepaintBoundary(
                    child: _buildShimmerTextStub(
                      _referenceStubWidth,
                      delay: 0.18,
                    ),
                  ),
                  const SizedBox(height: 18),
                  RepaintBoundary(
                    child: _buildImagePlaceholder(imageAspectRatio),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseDot(Color color, double phase) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = (_controller.value + phase) % 1.0;
        final scale = 0.85 + (0.35 * (1 - (t - 0.5).abs() * 2));
        final alpha = (0.45 + (0.55 * (1 - (t - 0.5).abs() * 2))).clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withValues(alpha: alpha),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerTextStub(
    double stubWidth, {
    required double delay,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final base = _AppChromePalette.panelElevated.withValues(alpha: 0.92);
        final glow = const Color(0xFF7DD3FC).withValues(alpha: 0.88);
        final shift = ((_controller.value + delay) % 1.0);
        return FractionallySizedBox(
          alignment: Alignment.centerLeft,
          child: Container(
            width: stubWidth,
            height: 13,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment(-1.0 + shift * 2.2, 0),
                end: Alignment(-0.2 + shift * 2.2, 0),
                colors: [
                  base,
                  glow,
                  base,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }

  double _measureStubWidth(String text) {
    final painter = TextPainter(
      text: const TextSpan(style: _stubTextStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..text = TextSpan(text: text, style: _stubTextStyle)
      ..layout();
    return painter.width + 18;
  }

  double _resolvePlaceholderAspectRatio(String value) {
    switch (value) {
      case '1536x1024':
        return 3 / 2;
      case '1024x1536':
        return 2 / 3;
      case '2048x1152':
      case '3840x2160':
        return 16 / 9;
      case '2160x3840':
        return 9 / 16;
      case '1024x1024':
      case '2048x2048':
      case 'auto':
      default:
        return 1.0;
    }
  }

  Widget _buildImagePlaceholder(double aspectRatio) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shift = _controller.value;
        final base = _AppChromePalette.panelElevated.withValues(alpha: 0.86);
        final glowA = const Color(0xFF7DD3FC).withValues(alpha: 0.84);
        final glowB = const Color(0xFF93C5FD).withValues(alpha: 0.72);

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 232,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _AppChromePalette.borderSoft,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment(-1.2 + shift * 2.4, -0.8),
                    end: Alignment(-0.1 + shift * 2.4, 0.8),
                    colors: [
                      base,
                      glowA,
                      glowB,
                      base,
                    ],
                    stops: const [0.0, 0.35, 0.62, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.10),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_search_rounded,
                        size: 34,
                        color: _AppChromePalette.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrushSelectionPainter extends CustomPainter {
  final List<Offset> points;
  final double brushRadius;
  final bool isActive;
  final Rect? imageViewportRect;

  const _BrushSelectionPainter({
    required this.points,
    required this.brushRadius,
    this.isActive = false,
    this.imageViewportRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.24);
    final viewportRect = imageViewportRect ?? (Offset.zero & size);
    canvas.drawRect(viewportRect, overlayPaint);

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(viewportRect, overlayPaint);
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = brushRadius * 2;
    if (points.length == 1) {
      canvas.drawCircle(points.first, brushRadius, clearPaint);
    } else if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, clearPaint);
    }
    canvas.restore();

    final strokePaint = Paint()
      ..color = isActive
          ? const Color(0xFF2563EB)
          : const Color(0xFF1D4ED8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = brushRadius * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (points.length == 1) {
      canvas.drawCircle(points.first, brushRadius, strokePaint);
    } else if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BrushSelectionPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.brushRadius != brushRadius ||
        oldDelegate.isActive != isActive ||
        oldDelegate.imageViewportRect != imageViewportRect;
  }
}

class _BrushCursorPainter extends CustomPainter {
  final Offset center;
  final double brushRadius;
  final bool isActive;
  final Rect? imageViewportRect;

  const _BrushCursorPainter({
    required this.center,
    required this.brushRadius,
    required this.isActive,
    this.imageViewportRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final viewportRect = imageViewportRect ?? (Offset.zero & size);
    if (!viewportRect.contains(center)) {
      return;
    }
    final fillPaint = Paint()
      ..color = const Color(0xFF2563EB).withValues(
        alpha: isActive ? 0.12 : 0.08,
      )
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = isActive ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, brushRadius, fillPaint);
    canvas.drawCircle(center, brushRadius, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _BrushCursorPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.brushRadius != brushRadius ||
        oldDelegate.isActive != isActive ||
        oldDelegate.imageViewportRect != imageViewportRect;
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                '当前应用会在本地保存：会话、消息、生图历史和授权状态。AI 生图请求中的提示词和参考图会发送到云端服务处理。',
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
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.errorContainer.withValues(
                            alpha: 0.36,
                          ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '清空全部本地数据',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '会删除本地会话、聊天记录、生图历史、授权状态和隐私确认状态。此操作不可恢复。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonal(
                        onPressed: onClearAllData,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('立即清空本地数据'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptTemplateCategory {
  final String id;
  final String title;
  final String description;
  final String file;

  const _PromptTemplateCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.file,
  });

  factory _PromptTemplateCategory.fromJson(Map<String, dynamic> json) {
    return _PromptTemplateCategory(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      file: json['file'] as String? ?? '',
    );
  }
}

class _PromptTemplateItem {
  final String title;
  final String prompt;
  final String? summary;
  final String? coverUrl;
  final String? source;

  const _PromptTemplateItem({
    required this.title,
    required this.prompt,
    this.summary,
    this.coverUrl,
    this.source,
  });

  factory _PromptTemplateItem.fromJson(Map<String, dynamic> json) {
    return _PromptTemplateItem(
      title: json['title'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      summary: json['summary'] as String?,
      coverUrl: json['coverUrl'] as String?,
      source: json['source'] as String?,
    );
  }
}

class _PromptTemplateLibrarySheet extends StatefulWidget {
  const _PromptTemplateLibrarySheet();

  @override
  State<_PromptTemplateLibrarySheet> createState() =>
      _PromptTemplateLibrarySheetState();
}

class _PromptTemplateLibrarySheetState
    extends State<_PromptTemplateLibrarySheet> {
  late final Future<List<_PromptTemplateCategory>> _categoriesFuture =
      _loadCategories();
  final Map<String, Future<List<_PromptTemplateItem>>> _templateFileCache = {};
  int _selectedCategoryIndex = 0;
  final ScrollController _categoryScrollController = ScrollController();

  Future<List<_PromptTemplateCategory>> _loadCategories() async {
    final raw = await rootBundle.loadString(
      'assets/prompt_templates/index.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final categories = (decoded['categories'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_PromptTemplateCategory.fromJson)
        .toList();
    return categories;
  }

  Future<List<_PromptTemplateItem>> _loadTemplatesFor(
    _PromptTemplateCategory category,
  ) {
    return _templateFileCache.putIfAbsent(category.file, () async {
      final raw = await rootBundle.loadString(category.file);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return (decoded['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_PromptTemplateItem.fromJson)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _AppChromePalette.panelGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: _AppChromePalette.border),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: _AppChromePalette.border.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
            child: Row(
              children: [
                Icon(
                  Icons.library_books_outlined,
                  color: _AppChromePalette.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '提示词模板库',
                    style: TextStyle(
                      color: _AppChromePalette.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<_PromptTemplateCategory>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '模板资源读取失败，请稍后再试。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  );
                }
                final categories = snapshot.data ?? const [];
                if (categories.isEmpty) {
                  return Center(
                    child: Text(
                      '当前没有可用模板。',
                      style: TextStyle(
                        color: _AppChromePalette.textMuted,
                      ),
                    ),
                  );
                }
                final selectedIndex =
                    _selectedCategoryIndex.clamp(0, categories.length - 1);
                final category = categories[selectedIndex];

                return FutureBuilder<List<_PromptTemplateItem>>(
                  future: _loadTemplatesFor(category),
                  builder: (context, templateSnapshot) {
                    final templates =
                        templateSnapshot.data ?? const <_PromptTemplateItem>[];
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                      children: [
                        Text(
                          '${category.title} · 共 ${templates.length} 个模板',
                          style: TextStyle(
                            color: _AppChromePalette.textMuted,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 42,
                          child: Row(
                            children: [
                              _CategoryScrollArrow(
                                icon: Icons.chevron_left_rounded,
                                onTap: () {
                                  if (!_categoryScrollController.hasClients) {
                                    return;
                                  }
                                  final next =
                                      (_categoryScrollController.offset - 220)
                                          .clamp(
                                            0,
                                            _categoryScrollController
                                                .position.maxScrollExtent,
                                          )
                                          .toDouble();
                                  _categoryScrollController.animateTo(
                                    next,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ScrollConfiguration(
                                  behavior:
                                      const MaterialScrollBehavior().copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                      PointerDeviceKind.trackpad,
                                    },
                                  ),
                                  child: ListView.separated(
                                    controller: _categoryScrollController,
                                    scrollDirection: Axis.horizontal,
                                    itemCount: categories.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final item = categories[index];
                                      final selected = index == selectedIndex;
                                      return InkWell(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        onTap: () => setState(() {
                                          _selectedCategoryIndex = index;
                                        }),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: selected
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFF10213D),
                                                      Color(0xFF172554),
                                                    ],
                                                  )
                                                : null,
                                            color: selected
                                                ? null
                                                : Colors.white
                                                    .withValues(alpha: 0.04),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: selected
                                                  ? _AppChromePalette.accent
                                                  : _AppChromePalette.borderSoft,
                                            ),
                                          ),
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              color: selected
                                                  ? Colors.white
                                                  : _AppChromePalette.text,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _CategoryScrollArrow(
                                icon: Icons.chevron_right_rounded,
                                onTap: () {
                                  if (!_categoryScrollController.hasClients) {
                                    return;
                                  }
                                  final next =
                                      (_categoryScrollController.offset + 220)
                                          .clamp(
                                            0,
                                            _categoryScrollController
                                                .position.maxScrollExtent,
                                          )
                                          .toDouble();
                                  _categoryScrollController.animateTo(
                                    next,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '左右滑动可查看更多分类',
                              style: TextStyle(
                                color: _AppChromePalette.textSoft,
                                fontSize: 11.5,
                              ),
                            ),
                            Text(
                              '${selectedIndex + 1}/${categories.length}',
                              style: TextStyle(
                                color: _AppChromePalette.textSoft,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          category.description,
                          style: TextStyle(
                            color: _AppChromePalette.textMuted,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (templateSnapshot.connectionState !=
                            ConnectionState.done)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final columns = width >= 1200
                                  ? 5
                                  : width >= 900
                                      ? 4
                                      : width >= 720
                                          ? 3
                                          : width >= 520
                                              ? 2
                                              : 1;
                              const spacing = 10.0;
                              final itemWidth =
                                  (width - spacing * (columns - 1)) / columns;
                              final columnBuckets = List.generate(
                                columns,
                                (_) => <_PromptTemplateItem>[],
                              );
                              for (var i = 0; i < templates.length; i++) {
                                columnBuckets[i % columns].add(templates[i]);
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var columnIndex = 0;
                                      columnIndex < columns;
                                      columnIndex++) ...[
                                    if (columnIndex > 0)
                                      const SizedBox(width: spacing),
                                    SizedBox(
                                      width: itemWidth,
                                      child: Column(
                                        children: [
                                          for (final item in columnBuckets[
                                              columnIndex]) ...[
                                            _PromptTemplateCard(item: item),
                                            const SizedBox(height: spacing),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptTemplateCard extends StatelessWidget {
  final _PromptTemplateItem item;

  const _PromptTemplateCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(item.title),
            content: SingleChildScrollView(
              child: SelectableText(
                item.prompt,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.7,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(item.prompt),
                child: const Text('使用模板'),
              ),
            ],
          ),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _AppChromePalette.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.coverUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    color: _AppChromePalette.panelElevated,
                    alignment: Alignment.center,
                    child: CachedNetworkImage(
                      imageUrl: item.coverUrl!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      memCacheWidth: 420,
                      maxWidthDiskCache: 960,
                      fadeInDuration: const Duration(milliseconds: 180),
                      placeholder: (context, url) => AspectRatio(
                        aspectRatio: 1,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _AppChromePalette.accent,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => AspectRatio(
                        aspectRatio: 1,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: _AppChromePalette.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _AppChromePalette.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.summary ?? item.prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _AppChromePalette.textMuted,
                  fontSize: 11.5,
                ),
              ),
              if (item.source != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 11,
                      color: _AppChromePalette.textSoft,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.source!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _AppChromePalette.textSoft,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(item.prompt),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('做同款'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryScrollArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryScrollArrow({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _AppChromePalette.borderSoft,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: _AppChromePalette.textMuted,
        ),
      ),
    );
  }
}
