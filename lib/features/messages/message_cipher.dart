import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptedMessageContent {
  const EncryptedMessageContent({
    required this.cipherText,
    required this.nonce,
    required this.mac,
    required this.version,
  });

  final String cipherText;
  final String nonce;
  final String mac;
  final int version;
}

abstract interface class MessageCipher {
  Future<EncryptedMessageContent> encrypt(
    String clearText, {
    required String messageId,
    required int revision,
  });

  Future<String> decrypt(
    EncryptedMessageContent content, {
    required String messageId,
    required int revision,
  });
}

abstract interface class MessageKeyProvider {
  Future<SecretKey> loadOrCreate();
}

class AesGcmMessageCipher implements MessageCipher {
  AesGcmMessageCipher(this._keyProvider, {Cipher? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  factory AesGcmMessageCipher.fromKeyBytes(List<int> bytes) =>
      AesGcmMessageCipher(StaticMessageKeyProvider(bytes));

  static const currentVersion = 1;

  final MessageKeyProvider _keyProvider;
  final Cipher _algorithm;

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

class StaticMessageKeyProvider implements MessageKeyProvider {
  StaticMessageKeyProvider(List<int> bytes)
    : _key = SecretKeyData(List<int>.unmodifiable(bytes)) {
    if (bytes.length != 32) {
      throw ArgumentError.value(bytes.length, 'bytes.length', 'Must be 32');
    }
  }

  final SecretKey _key;

  @override
  Future<SecretKey> loadOrCreate() async => _key;
}

class SecureStorageMessageKeyProvider implements MessageKeyProvider {
  SecureStorageMessageKeyProvider({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'tether.message-key.v1';
  final FlutterSecureStorage _storage;
  Future<SecretKey>? _pendingKey;

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
