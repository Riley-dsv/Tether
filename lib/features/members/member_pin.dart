import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Persistable result of deriving a PIN verifier.
class MemberPinVerifier {
  const MemberPinVerifier({
    required this.hash,
    required this.salt,
    required this.algorithm,
    required this.version,
    required this.iterations,
    this.memory,
    this.parallelism,
  });

  final String hash;
  final String salt;
  final String algorithm;
  final int version;
  final int iterations;
  final int? memory;
  final int? parallelism;
}

/// Derives salted PIN verifiers without retaining plaintext PINs.
class MemberPinCodec {
  MemberPinCodec({
    this.iterations = 2,
    this.memory = 19456,
    this.parallelism = 1,
    this.runInBackground = true,
    List<int> Function()? createSalt,
  }) : _createSalt = createSalt ?? _secureSalt;

  final int iterations;
  final int memory;
  final int parallelism;
  final bool runInBackground;
  final List<int> Function() _createSalt;

  static const argon2idAlgorithm = 'argon2id';
  static const legacyPbkdf2Algorithm = 'pbkdf2-sha256';
  static const currentVersion = 2;

  /// Accepts numeric PINs between four and twelve digits.
  static bool isValid(String pin) => RegExp(r'^\d{4,12}$').hasMatch(pin);

  Future<MemberPinVerifier> derive(String pin) async {
    if (!isValid(pin)) throw ArgumentError.value(pin, 'pin');
    final salt = _createSalt();
    final verifier = MemberPinVerifier(
      hash: '',
      salt: base64Encode(salt),
      algorithm: argon2idAlgorithm,
      version: currentVersion,
      iterations: iterations,
      memory: memory,
      parallelism: parallelism,
    );
    final hash = await _derive(pin, salt, verifier);
    return MemberPinVerifier(
      hash: base64Encode(hash),
      salt: verifier.salt,
      algorithm: verifier.algorithm,
      version: verifier.version,
      iterations: iterations,
      memory: memory,
      parallelism: parallelism,
    );
  }

  Future<bool> verify(String pin, MemberPinVerifier verifier) async {
    if (!isValid(pin)) return false;
    final expected = base64Decode(verifier.hash);
    final actual = await _derive(pin, base64Decode(verifier.salt), verifier);
    if (expected.length != actual.length) return false;
    var difference = 0;
    for (var index = 0; index < expected.length; index++) {
      difference |= expected[index] ^ actual[index];
    }
    return difference == 0;
  }

  bool needsUpgrade(MemberPinVerifier verifier) =>
      verifier.algorithm != argon2idAlgorithm ||
      verifier.version != currentVersion ||
      verifier.iterations != iterations ||
      verifier.memory != memory ||
      verifier.parallelism != parallelism;

  Future<List<int>> _derive(
    String pin,
    List<int> salt,
    MemberPinVerifier verifier,
  ) => runInBackground
      ? Isolate.run(() => _deriveDirect(pin, salt, verifier))
      : _deriveDirect(pin, salt, verifier);

  static Future<List<int>> _deriveDirect(
    String pin,
    List<int> salt,
    MemberPinVerifier verifier,
  ) async {
    final KdfAlgorithm algorithm;
    switch (verifier.algorithm) {
      case argon2idAlgorithm:
        final memory = verifier.memory;
        final parallelism = verifier.parallelism;
        if (memory == null || parallelism == null) {
          throw const FormatException('Missing Argon2id parameters');
        }
        algorithm = Argon2id(
          memory: memory,
          parallelism: parallelism,
          iterations: verifier.iterations,
          hashLength: 32,
        );
        break;
      case legacyPbkdf2Algorithm:
        algorithm = Pbkdf2.hmacSha256(
          iterations: verifier.iterations,
          bits: 256,
        );
        break;
      default:
        throw FormatException('Unsupported PIN KDF: ${verifier.algorithm}');
    }
    final key = await algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    return key.extractBytes();
  }

  static List<int> _secureSalt() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }
}
