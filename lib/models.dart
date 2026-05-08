import 'dart:typed_data';

enum Role { user, bot }

class ChatImageAttachment {
  final Uint8List bytes;
  final String name;
  final String mimeType;

  ChatImageAttachment({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });
}

class GeneratedImageAsset {
  final Uint8List? bytes;
  final String? imageUrl;
  final String fileName;
  final String mimeType;

  const GeneratedImageAsset({
    this.bytes,
    this.imageUrl,
    required this.fileName,
    required this.mimeType,
  }) : assert(
          (bytes != null && imageUrl == null) ||
              (bytes == null && imageUrl != null),
          'GeneratedImageAsset 必须提供 bytes 或 imageUrl 中的一个。',
        );

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
  bool get hasUrl => imageUrl != null && imageUrl!.isNotEmpty;
}

class ImageGenerationOptions {
  static const List<String> availableSizes = [
    'auto',
    '1024x1024',
    '1536x1024',
    '1024x1536',
    '2048x2048',
    '2048x1152',
    '3840x2160',
    '2160x3840',
  ];

  static const List<String> availableQualities = [
    'auto',
    'low',
    'medium',
    'high',
  ];

  static const double unitPriceUsd = 0.08;

  final String size;
  final String quality;

  const ImageGenerationOptions({
    required this.size,
    required this.quality,
  });

  factory ImageGenerationOptions.defaults() {
    return const ImageGenerationOptions(
      size: 'auto',
      quality: 'auto',
    );
  }

  ImageGenerationOptions copyWith({
    String? size,
    String? quality,
  }) {
    return ImageGenerationOptions(
      size: size ?? this.size,
      quality: quality ?? this.quality,
    ).normalized();
  }

  ImageGenerationOptions normalized() {
    final normalizedSize =
        availableSizes.contains(size) ? size : availableSizes.first;
    final normalizedQuality = availableQualities.contains(quality)
        ? quality
        : availableQualities.first;

    return ImageGenerationOptions(
      size: normalizedSize,
      quality: normalizedQuality,
    );
  }

  double get priceUsd => unitPriceUsd;

  String get summary =>
      '${displaySizeLabel(size)} · ${displayQualityLabel(quality)}';

  static String displaySizeLabel(String value) {
    switch (value) {
      case '1024x1024':
        return '1:1';
      case '1536x1024':
        return '3:2';
      case '1024x1536':
        return '2:3';
      case '2048x2048':
        return '1:1（2K）';
      case '2048x1152':
        return '16:9（2K）';
      case '3840x2160':
        return '16:9（4K）';
      case '2160x3840':
        return '9:16（4K）';
      case 'auto':
      default:
        return '自动';
    }
  }

  static String displayQualityLabel(String value) {
    switch (value) {
      case 'low':
        return '低质量';
      case 'medium':
        return '中等质量';
      case 'high':
        return '高质量';
      case 'auto':
      default:
        return '自动';
    }
  }
}

class ChatMessage {
  final int? id;
  final String text;
  final Role role;
  final DateTime createdAt;
  final List<GeneratedImageAsset> generatedImages;
  final List<ChatImageAttachment> localImages;
  final ImageGenerationOptions? generationOptions;

  ChatMessage({
    this.id,
    required this.text,
    required this.role,
    this.generatedImages = const [],
    this.localImages = const [],
    this.generationOptions,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasImages => generatedImages.isNotEmpty || localImages.isNotEmpty;
}

class ChatSessionInfo {
  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastActivatedAt;
  final int messageCount;

  const ChatSessionInfo({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.lastActivatedAt,
    required this.messageCount,
  });

  DateTime get sortTime => lastActivatedAt ?? updatedAt;
}

class GeneratedImageHistoryEntry {
  final int id;
  final int sessionId;
  final int messageId;
  final String sessionTitle;
  final String messageText;
  final DateTime createdAt;
  final String? size;
  final String? quality;
  final GeneratedImageAsset image;

  const GeneratedImageHistoryEntry({
    required this.id,
    required this.sessionId,
    required this.messageId,
    required this.sessionTitle,
    required this.messageText,
    required this.createdAt,
    required this.size,
    required this.quality,
    required this.image,
  });
}

class LicenseStatus {
  static const int defaultTrialGenerationLimit = 3;

  final String installId;
  final bool workerConfigured;
  final bool isDevelopmentBypass;
  final String? licenseToken;
  final String? tier;
  final DateTime? expiresAt;
  final DateTime? lastValidatedAt;
  final int trialUsageCount;
  final int trialUsageLimit;

  const LicenseStatus({
    required this.installId,
    required this.workerConfigured,
    required this.isDevelopmentBypass,
    required this.licenseToken,
    required this.tier,
    required this.expiresAt,
    required this.lastValidatedAt,
    required this.trialUsageCount,
    required this.trialUsageLimit,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isActivated =>
      licenseToken != null && licenseToken!.isNotEmpty && !isExpired;

  bool get isPremium => isDevelopmentBypass || isActivated;

  int get remainingTrialUses {
    if (isDevelopmentBypass) {
      return trialUsageLimit;
    }

    final remaining = trialUsageLimit - trialUsageCount;
    return remaining > 0 ? remaining : 0;
  }

  bool get canUseGeneration {
    if (isDevelopmentBypass) {
      return true;
    }
    return isPremium;
  }

  String get badgeLabel {
    if (isDevelopmentBypass) {
      return '开发模式';
    }
    if (isPremium) {
      return tier == null || tier!.isEmpty ? '高级版' : '${tier!} 已激活';
    }
    return '试用剩余 $remainingTrialUses 次';
  }

  String get summaryText {
    if (isDevelopmentBypass) {
      return '当前未启用商业授权校验，客户端会直接使用本地开发配置请求上游接口。';
    }
    if (isPremium) {
      final expiryText = expiresAt == null
          ? '永久授权'
          : '有效期至 ${expiresAt!.year}-${expiresAt!.month.toString().padLeft(2, '0')}-${expiresAt!.day.toString().padLeft(2, '0')}';
      return '${tier ?? '高级版'}已激活，$expiryText。';
    }
    return '当前已启用商业授权校验，请先输入激活码后再使用生成能力。';
  }

  LicenseStatus copyWith({
    String? installId,
    bool? workerConfigured,
    bool? isDevelopmentBypass,
    String? licenseToken,
    bool clearLicenseToken = false,
    String? tier,
    bool clearTier = false,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    DateTime? lastValidatedAt,
    bool clearLastValidatedAt = false,
    int? trialUsageCount,
    int? trialUsageLimit,
  }) {
    return LicenseStatus(
      installId: installId ?? this.installId,
      workerConfigured: workerConfigured ?? this.workerConfigured,
      isDevelopmentBypass: isDevelopmentBypass ?? this.isDevelopmentBypass,
      licenseToken:
          clearLicenseToken ? null : (licenseToken ?? this.licenseToken),
      tier: clearTier ? null : (tier ?? this.tier),
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      lastValidatedAt: clearLastValidatedAt
          ? null
          : (lastValidatedAt ?? this.lastValidatedAt),
      trialUsageCount: trialUsageCount ?? this.trialUsageCount,
      trialUsageLimit: trialUsageLimit ?? this.trialUsageLimit,
    );
  }
}
