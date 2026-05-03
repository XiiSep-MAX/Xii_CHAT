import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> main(List<String> args) async {
  if (args.length != 6) {
    stderr.writeln(
      'Usage: dart run tool/prepare_version_metadata.dart '
      '<version.json path> <zip path> <hash output path> <public hash file path> '
      '<latest hash public file path> <download url>',
    );
    exitCode = 64;
    return;
  }

  final versionFile = File(args[0]);
  final zipFile = File(args[1]);
  final hashOutputFile = File(args[2]);
  final publicHashFile = File(args[3]);
  final latestPublicHashFile = File(args[4]);
  final downloadUrl = args[5];

  if (!await versionFile.exists()) {
    stderr.writeln('version.json not found: ${versionFile.path}');
    exitCode = 65;
    return;
  }
  if (!await zipFile.exists()) {
    stderr.writeln('ZIP package not found: ${zipFile.path}');
    exitCode = 66;
    return;
  }

  final sha256Hex = await _computeSha256(zipFile);
  await hashOutputFile.parent.create(recursive: true);
  await publicHashFile.parent.create(recursive: true);
  await latestPublicHashFile.parent.create(recursive: true);

  await hashOutputFile.writeAsString('$sha256Hex\n');
  await publicHashFile.writeAsString(
    '$sha256Hex  ${zipFile.uri.pathSegments.last}\n',
  );
  await latestPublicHashFile.writeAsString(
    '$sha256Hex  ${zipFile.uri.pathSegments.last}\n',
  );

  final jsonMap =
      jsonDecode(await versionFile.readAsString()) as Map<String, dynamic>;
  jsonMap['downloadUrl'] = downloadUrl;
  jsonMap['sha256'] = sha256Hex;
  jsonMap['signature'] = '';

  const encoder = JsonEncoder.withIndent('  ');
  await versionFile.writeAsString('${encoder.convert(jsonMap)}\n');

  stdout.writeln('Prepared version metadata: ${versionFile.path}');
  stdout.writeln('SHA-256: $sha256Hex');
}

Future<String> _computeSha256(File file) async {
  final chunks = <int>[];
  await for (final chunk in file.openRead()) {
    chunks.addAll(chunk);
  }
  return sha256.convert(chunks).toString().toLowerCase();
}
