import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

  final privateKeyBase64 = base64Encode(privateKeyBytes);
  final publicKeyBase64 = base64Encode(publicKey.bytes);

  stdout.writeln('Update metadata signing key generated.');
  stdout.writeln('');
  stdout.writeln('Private key (keep secret):');
  stdout.writeln(privateKeyBase64);
  stdout.writeln('');
  stdout.writeln('Public key (embed in app):');
  stdout.writeln(publicKeyBase64);
  stdout.writeln('');
  stdout.writeln('Suggested next step:');
  stdout.writeln(
    '  Set UPDATE_METADATA_SIGNING_PRIVATE_KEY in your shell or .env before running build_release.bat',
  );
}
