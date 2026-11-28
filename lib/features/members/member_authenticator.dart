import 'dart:async';

import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/members/attribution_identity.dart';
import 'package:note_app/features/members/member_repository.dart';

enum AuthenticationResult {
  granted,
  denied,
  rateLimited,
  requiresPinSetup,
  notAuthenticatable,
}

abstract interface class MemberAuthentication {
  Future<AuthenticationResult> authenticate(
    AttributionIdentity identity,
    String pin,
  );

  Future<AuthenticationResult> changePin({
    required AttributionIdentity identity,
    required String currentPin,
    required String newPin,
  });
}

/// Authenticates member attribution against a persisted global failure budget.
class MemberAuthenticator implements MemberAuthentication {
  MemberAuthenticator({
    required AppDatabase database,
    required MemberStore members,
    DateTime Function()? now,
    this.maximumAttempts = 5,
    this.lockDuration = const Duration(seconds: 30),
  }) : _database = database,
       _members = members,
       _now = now ?? DateTime.now;

  final AppDatabase _database;
  final MemberStore _members;
  final DateTime Function() _now;
  final int maximumAttempts;
  final Duration lockDuration;
  Future<void> _tail = Future.value();

  /// Attempts authentication, serializing calls made through this instance.
  @override
  Future<AuthenticationResult> authenticate(
    AttributionIdentity identity,
    String pin,
  ) => _serialized(() => _authenticate(identity, pin));

  /// Changes a PIN only after the current PIN grants authentication.
  @override
  Future<AuthenticationResult> changePin({
    required AttributionIdentity identity,
    required String currentPin,
    required String newPin,
  }) => _serialized(() async {
    final result = await _authenticate(identity, currentPin);
    if (result != AuthenticationResult.granted) return result;
    await _members.setPin(
      memberId: identity.authenticatableMember!.id,
      pin: newPin,
    );
    return AuthenticationResult.granted;
  });

  Future<AuthenticationResult> _authenticate(
    AttributionIdentity identity,
    String pin,
  ) async {
    final member = identity.authenticatableMember;
    if (member == null) return AuthenticationResult.notAuthenticatable;
    if (!member.hasPin) return AuthenticationResult.requiresPinSetup;

    final now = _now().toUtc();
    if (await _isBlocked(now)) return AuthenticationResult.rateLimited;

    bool accepted;
    try {
      accepted = await _members.verifyPin(memberId: member.id, pin: pin);
    } on StateError {
      return AuthenticationResult.denied;
    }
    if (accepted) {
      await _resetFailures(now);
      return AuthenticationResult.granted;
    }
    return _recordFailure(now);
  }

  Future<bool> _isBlocked(DateTime now) async {
    final db = await _database.database;
    final row = (await db.query(
      'authentication_security',
      where: 'id = 1',
      limit: 1,
    )).single;
    final value = row['blocked_until'] as String?;
    if (value == null) return false;
    final blockedUntil = DateTime.parse(value);
    if (blockedUntil.isAfter(now)) return true;
    await _resetFailures(now);
    return false;
  }

  Future<AuthenticationResult> _recordFailure(DateTime now) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      await txn.rawUpdate(
        '''
        UPDATE authentication_security
        SET failed_attempts = failed_attempts + 1, updated_at = ?
        WHERE id = 1
        ''',
        [now.toIso8601String()],
      );
      final row = (await txn.query(
        'authentication_security',
        where: 'id = 1',
        limit: 1,
      )).single;
      final failures = row['failed_attempts'] as int;
      if (failures < maximumAttempts) return AuthenticationResult.denied;
      await txn.update('authentication_security', {
        'blocked_until': now.add(lockDuration).toIso8601String(),
      }, where: 'id = 1');
      return AuthenticationResult.rateLimited;
    });
  }

  Future<void> _resetFailures(DateTime now) async {
    final db = await _database.database;
    await db.update('authentication_security', {
      'failed_attempts': 0,
      'blocked_until': null,
      'updated_at': now.toIso8601String(),
    }, where: 'id = 1');
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
