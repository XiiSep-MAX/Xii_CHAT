import 'dart:typed_data';

import 'package:path/path.dart' as path;

class ResolvedImageDownloadMetadata {
  final String fileName;
  final String mimeType;

  const ResolvedImageDownloadMetadata({
    required this.fileName,
    required this.mimeType,
  });
}

class _ImageFileType {
  final String extension;
  final String mimeType;

  const _ImageFileType({
    required this.extension,
    required this.mimeType,
  });
}

const _pngType = _ImageFileType(extension: '.png', mimeType: 'image/png');
const _jpegType = _ImageFileType(extension: '.jpg', mimeType: 'image/jpeg');
const _webpType = _ImageFileType(extension: '.webp', mimeType: 'image/webp');
const _gifType = _ImageFileType(extension: '.gif', mimeType: 'image/gif');
const _bmpType = _ImageFileType(extension: '.bmp', mimeType: 'image/bmp');
const _heicType = _ImageFileType(extension: '.heic', mimeType: 'image/heic');
const _avifType = _ImageFileType(extension: '.avif', mimeType: 'image/avif');

ResolvedImageDownloadMetadata resolveImageDownloadMetadata({
  required String fileName,
  String? imageUrl,
  String? contentType,
  Uint8List? bytes,
}) {
  final inferredType =
          _detectTypeFromBytes(bytes) ??
          _detectTypeFromContentType(contentType) ??
          _detectTypeFromUrl(imageUrl) ??
          _detectTypeFromFileName(fileName) ??
          _pngType;
  final normalizedName = _normalizeFileName(
    fileName: fileName,
    imageUrl: imageUrl,
    extension: inferredType.extension,
  );

  return ResolvedImageDownloadMetadata(
    fileName: normalizedName,
    mimeType: inferredType.mimeType,
  );
}

String _normalizeFileName({
  required String fileName,
  required String? imageUrl,
  required String extension,
}) {
  final trimmedName = fileName.trim();
  final fallbackFromUrl = _fileNameFromUrl(imageUrl);
  final baseName = trimmedName.isNotEmpty
      ? trimmedName
      : (fallbackFromUrl ?? 'image_${DateTime.now().millisecondsSinceEpoch}');
  final currentExtension = path.extension(baseName);
  final baseWithoutExtension = currentExtension.isEmpty
      ? baseName
      : baseName.substring(0, baseName.length - currentExtension.length);
  final safeBaseName = baseWithoutExtension.trim().isEmpty
      ? 'image_${DateTime.now().millisecondsSinceEpoch}'
      : baseWithoutExtension;

  return '$safeBaseName$extension';
}

_ImageFileType? _detectTypeFromBytes(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) {
    return null;
  }

  if (_matchesHeader(bytes, const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ])) {
    return _pngType;
  }

  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return _jpegType;
  }

  if (_matchesAscii(bytes, 0, 'GIF87a') || _matchesAscii(bytes, 0, 'GIF89a')) {
    return _gifType;
  }

  if (_matchesAscii(bytes, 0, 'BM')) {
    return _bmpType;
  }

  if (_matchesAscii(bytes, 0, 'RIFF') && _matchesAscii(bytes, 8, 'WEBP')) {
    return _webpType;
  }

  if (_matchesAscii(bytes, 4, 'ftyp')) {
    final brand = _readAscii(bytes, 8, 4).toLowerCase();
    if (brand.startsWith('heic') ||
        brand.startsWith('heix') ||
        brand.startsWith('hevc') ||
        brand.startsWith('hevx') ||
        brand.startsWith('mif1')) {
      return _heicType;
    }
    if (brand.startsWith('avif')) {
      return _avifType;
    }
  }

  return null;
}

_ImageFileType? _detectTypeFromContentType(String? contentType) {
  final normalizedType = (contentType ?? '')
      .split(';')
      .first
      .trim()
      .toLowerCase();

  switch (normalizedType) {
    case 'image/jpeg':
    case 'image/jpg':
      return _jpegType;
    case 'image/webp':
      return _webpType;
    case 'image/gif':
      return _gifType;
    case 'image/bmp':
      return _bmpType;
    case 'image/heic':
    case 'image/heif':
      return _heicType;
    case 'image/avif':
      return _avifType;
    case 'image/png':
      return _pngType;
    default:
      return null;
  }
}

_ImageFileType? _detectTypeFromUrl(String? imageUrl) {
  final fileName = _fileNameFromUrl(imageUrl);
  if (fileName == null) {
    return null;
  }

  return _detectTypeFromFileName(fileName);
}

_ImageFileType? _detectTypeFromFileName(String fileName) {
  switch (path.extension(fileName).toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return _jpegType;
    case '.png':
      return _pngType;
    case '.webp':
      return _webpType;
    case '.gif':
      return _gifType;
    case '.bmp':
      return _bmpType;
    case '.heic':
    case '.heif':
      return _heicType;
    case '.avif':
      return _avifType;
    default:
      return null;
  }
}

String? _fileNameFromUrl(String? imageUrl) {
  final uri = Uri.tryParse(imageUrl ?? '');
  if (uri == null || uri.pathSegments.isEmpty) {
    return null;
  }

  final lastSegment = uri.pathSegments.last.trim();
  return lastSegment.isEmpty ? null : lastSegment;
}

bool _matchesHeader(Uint8List bytes, List<int> header) {
  if (bytes.length < header.length) {
    return false;
  }

  for (var index = 0; index < header.length; index++) {
    if (bytes[index] != header[index]) {
      return false;
    }
  }

  return true;
}

bool _matchesAscii(Uint8List bytes, int offset, String value) {
  if (bytes.length < offset + value.length) {
    return false;
  }

  for (var index = 0; index < value.length; index++) {
    if (bytes[offset + index] != value.codeUnitAt(index)) {
      return false;
    }
  }

  return true;
}

String _readAscii(Uint8List bytes, int offset, int length) {
  if (bytes.length < offset + length) {
    return '';
  }

  return String.fromCharCodes(bytes.sublist(offset, offset + length));
}
