import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serialized authenticated-encryption fields stored with one revision.
///
/// Values are Base64 strings so SQLite does not perform implicit text/blob
/// conversions. [version] selects the decoding contract, not the key version.
class EncryptedMessageContent {
  /// Creates a serialized encrypted payload.
  const EncryptedMessageContent({
    required this.cipherText,
    required this.nonce,
    required this.mac,
    required this.version,
  });

  /// Base64-encoded encrypted message bytes.
  final String cipherText;

  /// Base64-encoded unique nonce generated for this encryption operation.
  final String nonce;

  /// Base64-encoded authentication tag.
  final String mac;

  /// Payload format and algorithm version.
  final int version;
}

/// Authenticated encryption boundary for persisted message revisions.
///
/// Implementations must bind [messageId] and [revision] to the ciphertext so a
/// valid payload cannot be moved to another logical message or revision.
abstract interface class MessageCipher {
  /// Encrypts [clearText] for exactly one logical message revision.
  Future<EncryptedMessageContent> encrypt(
    String clearText, {
    required String messageId,
    required int revision,
  });

  /// Authenticates and decrypts [content].
  ///
  /// Throws when authentication fails, the key is unavailable, or the payload
  /// version is unsupported. Callers must not substitute damaged plaintext.
  Future<String> decrypt(
    EncryptedMessageContent content, {
    required String messageId,
    required int revision,
  });
}

/// Supplies the stable master key used by [MessageCipher].
abstract interface class MessageKeyProvider {
  /// Returns the existing key or creates and persists it atomically.
  ///
  /// The same application database must always resolve to the same key.
  Future<SecretKey> loadOrCreate();
}

/// AES-256-GCM implementation of [MessageCipher].
///
/// The associated data is `messageId + revision`; this preserves integrity of
/// the revision graph in addition to authenticating the content bytes.
class AesGcmMessageCipher implements MessageCipher {
  /// Creates a cipher backed by [_keyProvider].
  AesGcmMessageCipher(this._keyProvider, {Cipher? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  /// Creates a deterministic cipher for tests and controlled migrations.
  ///
  /// [bytes] must contain exactly 32 bytes and must not be hard-coded in a
  /// production application.
  factory AesGcmMessageCipher.fromKeyBytes(List<int> bytes) =>
      AesGcmMessageCipher(StaticMessageKeyProvider(bytes));

  /// Current serialized payload format.
  static const currentVersion = 1;

  final MessageKeyProvider _keyProvider;
  final Cipher _algorithm;

  /// Encrypts with a fresh nonce and revision-bound associated data.
  @override
  Future<EncryptedMessageContent> encrypt(
    String clearText, {
    required String messageId,
    required int revision,
  }) async {
    final box = await _algorithm.encrypt(
      utf8.encode(clearText),
      secretKey: await _keyProvider.loadOrCreate(),
      aad: _associatedData(messageId, revision),
    );
    return EncryptedMessageContent(
      cipherText: base64Encode(box.cipherText),
      nonce: base64Encode(box.nonce),
      mac: base64Encode(box.mac.bytes),
      version: currentVersion,
    );
  }

  /// Verifies the authentication tag before returning UTF-8 plaintext.
  @override
  Future<String> decrypt(
    EncryptedMessageContent content, {
    required String messageId,
    required int revision,
  }) async {
    if (content.version != currentVersion) {
      throw StateError('Unsupported message encryption version');
    }
    final clearBytes = await _algorithm.decrypt(
      SecretBox(
        base64Decode(content.cipherText),
        nonce: base64Decode(content.nonce),
        mac: Mac(base64Decode(content.mac)),
      ),
      secretKey: await _keyProvider.loadOrCreate(),
      aad: _associatedData(messageId, revision),
    );
    return utf8.decode(clearBytes);
  }

  static List<int> _associatedData(String messageId, int revision) =>
      utf8.encode('tether-message:$messageId:$revision');
}

/// In-memory [MessageKeyProvider] intended for deterministic tests.
class StaticMessageKeyProvider implements MessageKeyProvider {
  /// Creates a provider for one 256-bit key.
  StaticMessageKeyProvider(List<int> bytes)
    : _key = SecretKeyData(List<int>.unmodifiable(bytes)) {
    if (bytes.length != 32) {
      throw ArgumentError.value(bytes.length, 'bytes.length', 'Must be 32');
    }
  }

  final SecretKey _key;

  /// Returns the same immutable key for every request.
  @override
  Future<SecretKey> loadOrCreate() async => _key;
}

/// Stores the message master key in the platform's protected key storage.
///
/// Concurrent callers share one pending read/create operation. A failed
/// operation is not cached, which allows a later unlock retry to succeed.
class SecureStorageMessageKeyProvider implements MessageKeyProvider {
  /// Creates a provider, optionally with injected storage for tests.
  SecureStorageMessageKeyProvider({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'tether.message-key.v1';
  final FlutterSecureStorage _storage;
  Future<SecretKey>? _pendingKey;

  /// Loads or creates the 256-bit key used by message encryption.
  @override
  Future<SecretKey> loadOrCreate() async {
    final pending = _pendingKey ??= _loadOrCreate();
    try {
      return await pending;
    } catch (_) {
      _pendingKey = null;
      rethrow;
    }
  }

  Future<SecretKey> _loadOrCreate() async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded != null) {
      final bytes = base64Decode(encoded);
      if (bytes.length != 32) {
        throw StateError('Stored message encryption key is invalid');
      }
      return SecretKeyData(bytes);
    }

    final key = await AesGcm.with256bits().newSecretKey();
    final bytes = await key.extractBytes();
    await _storage.write(key: _storageKey, value: base64Encode(bytes));
    return SecretKeyData(bytes);
  }
}
