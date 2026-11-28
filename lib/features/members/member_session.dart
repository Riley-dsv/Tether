import 'package:note_app/features/members/system_member.dart';

/// Capability captured by a protected screen at the time it is opened.
class MemberSessionLease {
  const MemberSessionLease({required this.memberId, required this.generation});

  final String memberId;
  final int generation;
}

/// In-memory member session with generation-based revocation and idle locking.
class MemberSession {
  MemberSession({
    DateTime Function()? now,
    this.backgroundTimeout = const Duration(minutes: 2),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration backgroundTimeout;
  String? _memberId;
  int _generation = 0;
  DateTime? _backgroundedAt;

  String? get memberId => _memberId;
  bool get isAnonymous => _memberId == null;

  /// Whether the current session owns [memberId].
  bool permitsMember(String memberId) => _memberId == memberId;

  /// Revokes the previous identity and starts a fresh member session.
  MemberSessionLease activate(SystemMember member) {
    _generation++;
    _memberId = member.id;
    _backgroundedAt = null;
    return MemberSessionLease(memberId: member.id, generation: _generation);
  }

  /// Revokes all member capabilities and returns to anonymous access.
  void useAnonymous() {
    _generation++;
    _memberId = null;
    _backgroundedAt = null;
  }

  /// Marks when protected content left the foreground.
  void background() {
    if (_memberId != null) _backgroundedAt ??= _now().toUtc();
  }

  /// Locks an expired member session and reports whether revocation occurred.
  bool resume() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (_memberId == null || backgroundedAt == null) return false;
    if (_now().toUtc().difference(backgroundedAt) < backgroundTimeout) {
      return false;
    }
    useAnonymous();
    return true;
  }

  /// Returns whether [lease] still authorizes its original member.
  bool permits(MemberSessionLease lease) =>
      _memberId == lease.memberId && _generation == lease.generation;
}
