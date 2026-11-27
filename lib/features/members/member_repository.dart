import 'package:note_app/database/app_database.dart';
import 'package:note_app/database/tables/message_tables.dart';
import 'package:note_app/features/members/member_pin.dart';
import 'package:note_app/features/members/system_member.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';

/// Persistence contract for active internal identities.
abstract interface class MemberStore {
  /// Lists active member profiles in display-name order.
  Future<List<SystemMember>> members();

  /// Creates a member and automatically joins them to the general space.
  Future<SystemMember> createMember(String displayName, {required String pin});

  /// Adds or replaces the PIN verifier for an existing active member.
  Future<void> setPin({required String memberId, required String pin});

  /// Verifies [pin] against the member's stored salted verifier.
  Future<bool> verifyPin({required String memberId, required String pin});

  /// Changes presentation identity without rewriting historical attribution.
  Future<SystemMember> renameMember({
    required String memberId,
    required String displayName,
  });

  /// Removes a member from active selection while retaining historical rows.
  Future<void> archiveMember(String memberId);
}

/// SQLite implementation of [MemberStore].
///
/// Lifecycle mutations and their system-log events share one transaction.
/// Archiving is deliberately soft so historical authorship remains valid.
class MemberRepository implements MemberStore {
  /// Creates a member repository over [AppDatabase].
  MemberRepository(this._appDatabase, {MemberPinCodec? pinCodec})
    : _pinCodec = pinCodec ?? MemberPinCodec();

  final AppDatabase _appDatabase;
  final MemberPinCodec _pinCodec;
  int _sequence = 0;

  @override
  Future<List<SystemMember>> members() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'members',
      where: 'deleted_at IS NULL',
      orderBy: 'display_name COLLATE NOCASE',
    );
    return rows
        .map(
          (row) => SystemMember.fromStorage(
            id: row['id'] as String,
            name: row['display_name'] as String,
            hasPin: row['pin_hash'] != null,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<SystemMember> createMember(
    String displayName, {
    required String pin,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError.value(displayName, 'displayName');
    final verifier = await _pinCodec.derive(pin);
    final db = await _appDatabase.database;
    final id = _newId();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('members', {
        'id': id,
        'display_name': name,
        'created_at': now,
        'pin_hash': verifier.hash,
        'pin_salt': verifier.salt,
        'pin_iterations': verifier.iterations,
      });
      await txn.insert('conversation_members', {
        'conversation_id': MessageTables.generalConversationId,
        'member_id': id,
        'joined_at': now,
      });
      await SystemLogRepository.record(
        txn,
        type: 'member_created',
        summary: 'created member profile “$name”',
      );
    });
    return SystemMember.fromStorage(id: id, name: name, hasPin: true);
  }

  @override
  Future<void> setPin({required String memberId, required String pin}) async {
    final verifier = await _pinCodec.derive(pin);
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final updated = await txn.update(
        'members',
        {
          'pin_hash': verifier.hash,
          'pin_salt': verifier.salt,
          'pin_iterations': verifier.iterations,
        },
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [memberId],
      );
      if (updated == 0) throw StateError('Member no longer exists');
      await SystemLogRepository.record(
        txn,
        type: 'member_pin_set',
        summary: 'protected a member profile with a PIN',
      );
    });
  }

  @override
  Future<bool> verifyPin({
    required String memberId,
    required String pin,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'members',
      columns: ['pin_hash', 'pin_salt', 'pin_iterations'],
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [memberId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Member no longer exists');
    final row = rows.single;
    final hash = row['pin_hash'] as String?;
    final salt = row['pin_salt'] as String?;
    final iterations = row['pin_iterations'] as int?;
    if (hash == null || salt == null || iterations == null) return false;
    return _pinCodec.verify(
      pin,
      MemberPinVerifier(hash: hash, salt: salt, iterations: iterations),
    );
  }

  @override
  Future<SystemMember> renameMember({
    required String memberId,
    required String displayName,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError.value(displayName, 'displayName');
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final updated = await txn.update(
        'members',
        {'display_name': name},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [memberId],
      );
      if (updated == 0) throw StateError('Member no longer exists');
      await SystemLogRepository.record(
        txn,
        type: 'member_renamed',
        summary: 'renamed a member profile to “$name”',
      );
    });
    final rows = await db.query(
      'members',
      columns: ['pin_hash'],
      where: 'id = ?',
      whereArgs: [memberId],
      limit: 1,
    );
    return SystemMember.fromStorage(
      id: memberId,
      name: name,
      hasPin: rows.single['pin_hash'] != null,
    );
  }

  @override
  Future<void> archiveMember(String memberId) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final archived = await txn.update(
        'members',
        {'deleted_at': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [memberId],
      );
      if (archived == 0) throw StateError('Member no longer exists');
      await SystemLogRepository.record(
        txn,
        type: 'member_archived',
        summary: 'removed a member profile',
      );
    });
  }

  String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'member_${now}_${_sequence++}';
  }
}
