import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Persistable result of deriving a PIN verifier.
class MemberPinVerifier {
  const MemberPinVerifier({
    required this.hash,
    required this.salt,
    required this.iterations,
  });

  final String hash;
  final String salt;
  final int iterations;
}

/// Derives salted PIN verifiers without retaining plaintext PINs.
class MemberPinCodec {
  MemberPinCodec({
    this.iterations = 120000,
    this.runInBackground = true,
    List<int> Function()? createSalt,
  }) : _createSalt = createSalt ?? _secureSalt;

  final int iterations;
  final bool runInBackground;
  final List<int> Function() _createSalt;

  /// Accepts numeric PINs between four and twelve digits.
  static bool isValid(String pin) => RegExp(r'^\d{4,12}$').hasMatch(pin);

  Future<MemberPinVerifier> derive(String pin) async {
    if (!isValid(pin)) throw ArgumentError.value(pin, 'pin');
    final salt = _createSalt();
    final hash = await _derive(pin, salt, iterations);
    return MemberPinVerifier(
      hash: base64Encode(hash),
      salt: base64Encode(salt),
      iterations: iterations,
    );
  }

  Future<bool> verify(String pin, MemberPinVerifier verifier) async {
    if (!isValid(pin)) return false;
    final expected = base64Decode(verifier.hash);
    final actual = await _derive(
      pin,
      base64Decode(verifier.salt),
      verifier.iterations,
    );
    if (expected.length != actual.length) return false;
    var difference = 0;
    for (var index = 0; index < expected.length; index++) {
      difference |= expected[index] ^ actual[index];
    }
    return difference == 0;
  }

  Future<List<int>> _derive(String pin, List<int> salt, int iterations) =>
      runInBackground
      ? Isolate.run(() => _deriveDirect(pin, salt, iterations))
      : _deriveDirect(pin, salt, iterations);

  static Future<List<int>> _deriveDirect(
    String pin,
    List<int> salt,
    int iterations,
  ) async {
    final algorithm = Pbkdf2.hmacSha256(iterations: iterations, bits: 256);
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
