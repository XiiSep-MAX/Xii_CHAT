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
  static const List<String> commonAspectRatios = [
    '1:1',
    '3:2',
    '2:3',
    '4:3',
    '3:4',
    '5:4',
    '4:5',
    '16:9',
    '9:16',
  ];

  static const double unitPriceUsd = 0.08;

  final String aspectRatio;

  const ImageGenerationOptions({
    required this.aspectRatio,
  });

  factory ImageGenerationOptions.defaults() {
    return const ImageGenerationOptions(aspectRatio: '1:1');
  }

  ImageGenerationOptions copyWith({
    String? aspectRatio,
  }) {
    return ImageGenerationOptions(
      aspectRatio: aspectRatio ?? this.aspectRatio,
    ).normalized();
  }

  ImageGenerationOptions normalized() {
    final ratios = availableAspectRatios();
    final normalizedRatio =
        ratios.contains(aspectRatio) ? aspectRatio : ratios.first;

    return ImageGenerationOptions(
      aspectRatio: normalizedRatio,
    );
  }

  static List<String> availableAspectRatios() {
    return commonAspectRatios;
  }

  double get priceUsd => unitPriceUsd;

  String get summary => aspectRatio;
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
  final int switchCount;

  const ChatSessionInfo({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.lastActivatedAt,
    required this.messageCount,
    required this.switchCount,
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
  final String? aspectRatio;
  final GeneratedImageAsset image;

  const GeneratedImageHistoryEntry({
    required this.id,
    required this.sessionId,
    required this.messageId,
    required this.sessionTitle,
    required this.messageText,
    required this.createdAt,
    required this.aspectRatio,
    required this.image,
  });
}

class SessionSwitchLogEntry {
  final int id;
  final int sessionId;
  final DateTime switchedAt;

  const SessionSwitchLogEntry({
    required this.id,
    required this.sessionId,
    required this.switchedAt,
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
