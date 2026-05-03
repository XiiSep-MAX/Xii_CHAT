import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'env_config.dart';
import 'local_storage_service.dart';
import 'models.dart';

class LicenseActivationResult {
  final bool success;
  final String message;
  final LicenseStatus status;

  const LicenseActivationResult({
    required this.success,
    required this.message,
    required this.status,
  });
}

class LicenseService {
  LicenseService._();

  static final LicenseService instance = LicenseService._();

  static const _stateInstallIdKey = 'license_install_id';
  static const _stateTokenKey = 'license_token';
  static const _stateTierKey = 'license_tier';
  static const _stateExpiresAtKey = 'license_expires_at';
  static const _stateLastValidatedAtKey = 'license_last_validated_at';
  static const _stateTrialUsageCountKey = 'trial_usage_count';
  static const _defaultTrialUsageLimit =
      LicenseStatus.defaultTrialGenerationLimit;

  final LocalStorageService _storage = LocalStorageService.instance;

  String? get _workerBaseUrl {
    final raw = EnvConfig.get('LICENSE_API_BASE_URL')?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  bool get isWorkerConfigured =>
      _workerBaseUrl != null && _workerBaseUrl!.isNotEmpty;

  bool get isDevelopmentBypass => !isWorkerConfigured;

  Future<LicenseStatus> initialize() async {
    final installId = await _ensureInstallId();
    final token = await _storage.readAppState(_stateTokenKey);
    final tier = await _storage.readAppState(_stateTierKey);
    final expiresAtRaw = await _storage.readAppState(_stateExpiresAtKey);
    final lastValidatedAtRaw =
        await _storage.readAppState(_stateLastValidatedAtKey);
    final trialUsageCountRaw =
        await _storage.readAppState(_stateTrialUsageCountKey);

    return LicenseStatus(
      installId: installId,
      workerConfigured: isWorkerConfigured,
      isDevelopmentBypass: isDevelopmentBypass,
      licenseToken: token,
      tier: tier,
      expiresAt: _parseDateTime(expiresAtRaw),
      lastValidatedAt: _parseDateTime(lastValidatedAtRaw),
      trialUsageCount: int.tryParse(trialUsageCountRaw ?? '') ?? 0,
      trialUsageLimit: _defaultTrialUsageLimit,
    );
  }

  Future<LicenseStatus> refreshLicenseStatus() async {
    final current = await initialize();
    if (!isWorkerConfigured || !current.isActivated) {
      return current;
    }

    try {
      final response = await _postJson(
        '/v1/license/validate',
        {
          'token': current.licenseToken,
          'installId': current.installId,
        },
      );

      final updated = current.copyWith(
        tier: response['tier']?.toString(),
        expiresAt: _parseDateTime(response['expiresAt']?.toString()),
        lastValidatedAt: DateTime.now(),
      );
      await _persistLicenseStatus(updated);
      return updated;
    } catch (_) {
      return current;
    }
  }

  Future<LicenseActivationResult> activateCode(String code) async {
    final trimmedCode = code.trim();
    final current = await initialize();

    if (trimmedCode.isEmpty) {
      return LicenseActivationResult(
        success: false,
        message: '请输入激活码。',
        status: current,
      );
    }

    if (!isWorkerConfigured) {
      return LicenseActivationResult(
        success: false,
        message: '当前未配置授权服务地址，无法校验激活码。',
        status: current,
      );
    }

    try {
      final response = await _postJson(
        '/v1/license/activate',
        {
          'code': trimmedCode,
          'installId': current.installId,
        },
      );

      final updated = current.copyWith(
        licenseToken: response['token']?.toString(),
        tier: response['tier']?.toString(),
        expiresAt: _parseDateTime(response['expiresAt']?.toString()),
        lastValidatedAt: DateTime.now(),
      );
      await _persistLicenseStatus(updated);

      return LicenseActivationResult(
        success: true,
        message: response['message']?.toString() ?? '激活成功。',
        status: updated,
      );
    } catch (error) {
      return LicenseActivationResult(
        success: false,
        message: error.toString().replaceFirst('Exception: ', ''),
        status: current,
      );
    }
  }

  Future<LicenseStatus> consumeTrialUse() async {
    final current = await initialize();
    final next = current.copyWith(
      trialUsageCount: current.trialUsageCount + 1,
      lastValidatedAt: DateTime.now(),
    );
    await _storage.writeAppState(
      _stateTrialUsageCountKey,
      next.trialUsageCount.toString(),
    );
    return next;
  }

  Future<LicenseStatus> clearLicense() async {
    final current = await initialize();
    final next = current.copyWith(
      clearLicenseToken: true,
      clearTier: true,
      clearExpiresAt: true,
      clearLastValidatedAt: true,
    );
    await _storage.deleteAppState(_stateTokenKey);
    await _storage.deleteAppState(_stateTierKey);
    await _storage.deleteAppState(_stateExpiresAtKey);
    await _storage.deleteAppState(_stateLastValidatedAtKey);
    return next;
  }

  Future<String> _ensureInstallId() async {
    final saved = await _storage.readAppState(_stateInstallIdKey);
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }

    final generated = _generateInstallId();
    await _storage.writeAppState(_stateInstallIdKey, generated);
    return generated;
  }

  Future<void> _persistLicenseStatus(LicenseStatus status) async {
    if (status.licenseToken != null && status.licenseToken!.isNotEmpty) {
      await _storage.writeAppState(_stateTokenKey, status.licenseToken!);
    }
    if (status.tier != null && status.tier!.isNotEmpty) {
      await _storage.writeAppState(_stateTierKey, status.tier!);
    }
    if (status.expiresAt != null) {
      await _storage.writeAppState(
        _stateExpiresAtKey,
        status.expiresAt!.toIso8601String(),
      );
    }
    if (status.lastValidatedAt != null) {
      await _storage.writeAppState(
        _stateLastValidatedAtKey,
        status.lastValidatedAt!.toIso8601String(),
      );
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final baseUrl = _workerBaseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('未配置 LICENSE_API_BASE_URL。');
    }

    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final decoded = body.trim().isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(body) as Map<String, dynamic>);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded['error']?.toString() ??
            decoded['message']?.toString() ??
            '授权服务请求失败：HTTP ${response.statusCode}',
      );
    }

    return decoded;
  }

  DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  String _generateInstallId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final buffer = StringBuffer('xii-');
    for (final value in bytes) {
      buffer.write(value.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
