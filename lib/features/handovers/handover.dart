import 'package:note_app/features/members/system_member.dart';

/// Urgency used to order and highlight a handover.
enum HandoverPriority { low, normal, high, urgent }

/// One completed or outstanding item carried by a handover.
class HandoverItem {
  /// Creates an immutable handover item.
  const HandoverItem({required this.description, required this.isCompleted});

  /// Human-readable work or information item.
  final String description;

  /// Whether the item was already completed when handed over.
  final bool isCompleted;
}

/// Structured context transferred to explicitly selected recipients.
///
/// Handovers are never visible to an unknown viewer. [readBy] stores member
/// identifiers and does not imply monitoring beyond explicit acknowledgement.
class Handover {
  /// Creates an immutable handover projection.
  const Handover({
    required this.id,
    required this.summary,
    required this.priority,
    required this.context,
    required this.createdAt,
    required this.expiresAt,
    required this.author,
    required this.recipients,
    required this.items,
    required this.readBy,
  });

  /// Stable handover identifier.
  final String id;

  /// Short description of what recipients need to know.
  final String summary;

  /// User-selected urgency.
  final HandoverPriority priority;

  /// Optional supporting detail.
  final String? context;

  /// Creation instant.
  final DateTime createdAt;

  /// Optional instant after which the handover is no longer actionable.
  final DateTime? expiresAt;

  /// Attributed creator, or `null` for unknown attribution.
  final SystemMember? author;

  /// Explicit audience.
  final List<SystemMember> recipients;

  /// Completed and outstanding work transferred with the context.
  final List<HandoverItem> items;

  /// Member identifiers that explicitly acknowledged the handover.
  final Set<String> readBy;

  /// Whether [expiresAt] is earlier than the current instant.
  bool get isExpired => expiresAt?.isBefore(DateTime.now()) ?? false;
}
