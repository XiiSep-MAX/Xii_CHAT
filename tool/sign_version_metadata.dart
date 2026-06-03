import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
        'Usage: dart run tool/sign_version_metadata.dart <version.json path>');
    exitCode = 64;
    return;
  }

  final privateKeyBase64 =
      Platform.environment['UPDATE_METADATA_SIGNING_PRIVATE_KEY']?.trim() ?? '';
  if (privateKeyBase64.isEmpty) {
    stderr.writeln(
        'Missing UPDATE_METADATA_SIGNING_PRIVATE_KEY environment variable.');
    exitCode = 65;
    return;
  }

  final versionFile = File(args.single);
  if (!await versionFile.exists()) {
    stderr.writeln('version.json not found: ${versionFile.path}');
    exitCode = 66;
    return;
  }

  final jsonMap =
      jsonDecode(await versionFile.readAsString()) as Map<String, dynamic>;
  jsonMap.remove('signature');
  final payload = _canonicalJson(jsonMap);

  final algorithm = Ed25519();
  final privateKeyBytes = base64Decode(privateKeyBase64);
  final privateKeySeed = switch (privateKeyBytes.length) {
    32 => privateKeyBytes,
    64 => privateKeyBytes.sublist(0, 32),
    _ => throw ArgumentError(
        'UPDATE_METADATA_SIGNING_PRIVATE_KEY must decode to 32-byte seed or 64-byte private key, got ${privateKeyBytes.length} bytes.',
      ),
  };
  final privateKey = await algorithm.newKeyPairFromSeed(privateKeySeed);
  final signature = await algorithm.sign(
    utf8.encode(payload),
    keyPair: privateKey,
  );
  jsonMap['signature'] = base64Encode(signature.bytes);
  const encoder = JsonEncoder.withIndent('  ');
  await versionFile.writeAsString('${encoder.convert(jsonMap)}\n');

  stdout.writeln('Signed version metadata: ${versionFile.path}');
}

String _canonicalJson(Map<String, dynamic> map) {
  final sortedKeys = map.keys.toList()..sort();
  final canonicalMap = <String, dynamic>{};
  for (final key in sortedKeys) {
    canonicalMap[key] = map[key];
  }
  return jsonEncode(canonicalMap);
}
