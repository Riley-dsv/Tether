/// Actionable counts and the next scheduled item for one dashboard viewer.
///
/// A summary for an unknown viewer is intentionally empty so private activity
/// is not disclosed without selecting an identity.
class HomeSummary {
  /// Creates a populated dashboard summary.
  const HomeSummary({
    required this.unreadMessages,
    required this.importantHandovers,
    required this.tasksToday,
    this.nextItem,
  });

  /// Creates the privacy-safe summary used for an unknown viewer.
  const HomeSummary.empty()
    : unreadMessages = 0,
      importantHandovers = 0,
      tasksToday = 0,
      nextItem = null;

  /// Number of visible messages without a read receipt from the viewer.
  final int unreadMessages;

  /// Unread, unexpired handovers with high or urgent priority.
  final int importantHandovers;

  /// Incomplete tasks assigned to the viewer and due today.
  final int tasksToday;

  /// Earliest future reminder or deadline, if any.
  final HomeNextItem? nextItem;
}

/// A normalized reminder or deadline displayed by the dashboard.
class HomeNextItem {
  /// Creates a scheduled dashboard item.
  const HomeNextItem({
    required this.title,
    required this.at,
    required this.kind,
  });

  /// Task title.
  final String title;

  /// Scheduled instant.
  final DateTime at;

  /// Whether [at] came from a reminder or deadline.
  final HomeNextItemKind kind;
}

/// Source field used to select [HomeNextItem.at].
enum HomeNextItemKind { reminder, deadline }
