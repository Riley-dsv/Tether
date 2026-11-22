class HomeSummary {
  const HomeSummary({
    required this.unreadMessages,
    required this.importantHandovers,
    required this.tasksToday,
    this.nextItem,
  });

  const HomeSummary.empty()
    : unreadMessages = 0,
      importantHandovers = 0,
      tasksToday = 0,
      nextItem = null;

  final int unreadMessages;
  final int importantHandovers;
  final int tasksToday;
  final HomeNextItem? nextItem;
}

class HomeNextItem {
  const HomeNextItem({
    required this.title,
    required this.at,
    required this.kind,
  });
  final String title;
  final DateTime at;
  final HomeNextItemKind kind;
}

enum HomeNextItemKind { reminder, deadline }
