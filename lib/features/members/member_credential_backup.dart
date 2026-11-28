import 'dart:convert';

import 'package:note_app/database/app_database.dart';

/// Portable salted verifier for one existing member.
class MemberCredentialBackup {
  const MemberCredentialBackup({
    required this.memberId,
    required this.hash,
    required this.salt,
    required this.algorithm,
    required this.version,
    required this.iterations,
    this.memory,
    this.parallelism,
  });

  final String memberId;
  final String hash;
  final String salt;
  final String algorithm;
  final int version;
  final int iterations;
  final int? memory;
  final int? parallelism;
}

/// Exports and restores credential verifiers without handling plaintext PINs.
class MemberCredentialBackupService {
  MemberCredentialBackupService(this._database);

  final AppDatabase _database;

  Future<List<MemberCredentialBackup>> exportCredentials() async {
    final db = await _database.database;
    final rows = await db.query(
      'members',
      columns: [
        'id',
        'pin_hash',
        'pin_salt',
        'pin_kdf',
        'pin_version',
        'pin_iterations',
        'pin_memory',
        'pin_parallelism',
      ],
      where: 'pin_hash IS NOT NULL',
      orderBy: 'id',
    );
    return rows
        .map(
          (row) => MemberCredentialBackup(
            memberId: row['id'] as String,
            hash: row['pin_hash'] as String,
            salt: row['pin_salt'] as String,
            algorithm: row['pin_kdf'] as String,
            version: row['pin_version'] as int,
            iterations: row['pin_iterations'] as int,
            memory: row['pin_memory'] as int?,
            parallelism: row['pin_parallelism'] as int?,
          ),
        )
        .toList(growable: false);
  }

  Future<void> restoreCredentials(
    Iterable<MemberCredentialBackup> credentials,
  ) async {
    final records = credentials.toList(growable: false);
    for (final record in records) {
      _validate(record);
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final record in records) {
        final updated = await txn.update(
          'members',
          {
            'pin_hash': record.hash,
            'pin_salt': record.salt,
            'pin_kdf': record.algorithm,
            'pin_version': record.version,
            'pin_iterations': record.iterations,
            'pin_memory': record.memory,
            'pin_parallelism': record.parallelism,
          },
          where: 'id = ?',
          whereArgs: [record.memberId],
        );
        if (updated != 1) {
          throw StateError('Credential target is not an existing member');
        }
      }
    });
  }

  static void _validate(MemberCredentialBackup record) {
    final normalized = record.memberId.trim().toLowerCase();
    if (normalized == 'unknown' ||
        normalized == 'anonymous' ||
        normalized == 'collective') {
      throw StateError('Attribution-only identities cannot own credentials');
    }
    if (record.version <= 0 || record.iterations <= 0) {
      throw const FormatException('Work factor');
    }
    if (record.algorithm == 'argon2id' &&
        ((record.memory ?? 0) <= 0 || (record.parallelism ?? 0) <= 0)) {
      throw const FormatException('Argon2id parameters');
    }
    if (record.algorithm != 'argon2id' && record.algorithm != 'pbkdf2-sha256') {
      throw const FormatException('Unsupported KDF');
    }
    try {
      if (base64Decode(record.hash).isEmpty ||
          base64Decode(record.salt).isEmpty) {
        throw const FormatException('Empty credential material');
      }
    } on FormatException {
      throw const FormatException('Invalid credential encoding');
    }
  }
}
