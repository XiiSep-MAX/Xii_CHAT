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

class ImageResolutionOption {
  static const String oneK = '1k';
  static const String twoK = '2k';
  static const String fourK = '4k';

  static const List<String> values = [oneK, twoK, fourK];

  static String labelOf(String value) => value.toUpperCase();
}

class OutputFormatOption {
  static const String png = 'png';
  static const String jpeg = 'jpeg';
  static const String webp = 'webp';

  static const List<String> values = [png, jpeg, webp];

  static String labelOf(String value) => value.toUpperCase();
}

class ImageGenerationOptions {
  static const List<String> fullAspectRatios = [
    '1:1',
    '3:2',
    '2:3',
    '4:3',
    '3:4',
    '5:4',
    '4:5',
    '16:9',
    '9:16',
    '2:1',
    '1:2',
    '21:9',
    '9:21',
  ];

  static const List<String> fourKAspectRatios = [
    '16:9',
    '9:16',
    '2:1',
    '1:2',
    '21:9',
    '9:21',
  ];

  static const Map<String, double> resolutionPrices = {
    ImageResolutionOption.oneK: 0.08,
    ImageResolutionOption.twoK: 0.16,
    ImageResolutionOption.fourK: 0.32,
  };

  final String aspectRatio;
  final String resolution;
  final String outputFormat;

  const ImageGenerationOptions({
    required this.aspectRatio,
    required this.resolution,
    required this.outputFormat,
  });

  factory ImageGenerationOptions.defaults() {
    return const ImageGenerationOptions(
      aspectRatio: '1:1',
      resolution: ImageResolutionOption.oneK,
      outputFormat: OutputFormatOption.png,
    );
  }

  ImageGenerationOptions copyWith({
    String? aspectRatio,
    String? resolution,
    String? outputFormat,
  }) {
    return ImageGenerationOptions(
      aspectRatio: aspectRatio ?? this.aspectRatio,
      resolution: resolution ?? this.resolution,
      outputFormat: outputFormat ?? this.outputFormat,
    ).normalized();
  }

  ImageGenerationOptions normalized() {
    final normalizedResolution =
        ImageResolutionOption.values.contains(resolution)
            ? resolution
            : ImageResolutionOption.oneK;
    final normalizedFormat = OutputFormatOption.values.contains(outputFormat)
        ? outputFormat
        : OutputFormatOption.png;
    final ratios = availableAspectRatiosFor(normalizedResolution);
    final normalizedRatio =
        ratios.contains(aspectRatio) ? aspectRatio : ratios.first;

    return ImageGenerationOptions(
      aspectRatio: normalizedRatio,
      resolution: normalizedResolution,
      outputFormat: normalizedFormat,
    );
  }

  static List<String> availableAspectRatiosFor(String resolution) {
    if (resolution == ImageResolutionOption.fourK) {
      return fourKAspectRatios;
    }
    return fullAspectRatios;
  }

  double get priceUsd => resolutionPrices[resolution] ?? 0.08;

  String get summary =>
      '${ImageResolutionOption.labelOf(resolution)} · $aspectRatio · ${OutputFormatOption.labelOf(outputFormat)}';
}

String mimeTypeForOutputFormat(String outputFormat) {
  switch (outputFormat) {
    case OutputFormatOption.jpeg:
      return 'image/jpeg';
    case OutputFormatOption.webp:
      return 'image/webp';
    case OutputFormatOption.png:
    default:
      return 'image/png';
  }
}

String extensionForOutputFormat(String outputFormat) {
  switch (outputFormat) {
    case OutputFormatOption.jpeg:
      return 'jpg';
    case OutputFormatOption.webp:
      return 'webp';
    case OutputFormatOption.png:
    default:
      return 'png';
  }
}

class ChatMessage {
  final String text;
  final Role role;
  final DateTime createdAt;
  final List<GeneratedImageAsset> generatedImages;
  final List<ChatImageAttachment> localImages;
  final ImageGenerationOptions? generationOptions;

  ChatMessage({
    required this.text,
    required this.role,
    this.generatedImages = const [],
    this.localImages = const [],
    this.generationOptions,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasImages => generatedImages.isNotEmpty || localImages.isNotEmpty;
}
