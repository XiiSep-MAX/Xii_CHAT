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
