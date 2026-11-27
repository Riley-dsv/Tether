import 'package:note_app/features/members/system_member.dart';

/// Human-readable record of a meaningful system action.
///
/// Events explain what happened without replacing source objects or silently
/// assigning responsibility. Technical events can be filtered by the viewer.
class SystemEvent {
  /// Creates an immutable system-log projection.
  const SystemEvent({
    required this.id,
    required this.type,
    required this.summary,
    required this.isTechnical,
    required this.createdAt,
    required this.actor,
    required this.conversationTitle,
    this.relatedTaskId,
  });

  /// Monotonic database row identifier.
  final int id;

  /// Stable machine-readable event category.
  final String type;

  /// Human-readable, non-sensitive description.
  final String summary;

  /// Whether this event is implementation detail rather than user activity.
  final bool isTechnical;

  /// Event creation instant.
  final DateTime createdAt;

  /// Attributed actor, or `null` for unknown/system activity.
  final SystemMember? actor;

  /// Related conversation title when one exists.
  final String? conversationTitle;

  /// Related task identifier used for cross-feature navigation.
  final String? relatedTaskId;
}
