import 'package:material_ui/material_ui.dart';
import 'package:note_app/app/app_theme.dart';
import 'package:note_app/features/system_log/system_event.dart';
import 'package:note_app/shared/widgets/members/member_avatar.dart';

/// Cross-feature activity feed with optional technical events.
class SystemLogView extends StatelessWidget {
  /// Creates a system-log view from an immutable event projection.
  const SystemLogView({
    super.key,
    required this.events,
    required this.includeTechnical,
    required this.onTechnicalChanged,
    required this.onBack,
  });

  final List<SystemEvent> events;
  final bool includeTechnical;
  final ValueChanged<bool> onTechnicalChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFBFAF6),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
              const Expanded(
                child: Text(
                  'System log',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const Text(
                'Technical events',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              Switch(value: includeTechnical, onChanged: onTechnicalChanged),
            ],
          ),
        ),
        Expanded(
          child: events.isEmpty
              ? const Center(
                  child: Text(
                    'No events yet',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: events.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final local = event.createdAt.toLocal();
                    final time =
                        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 5),
                      leading: MemberAvatar(member: event.actor, size: 34),
                      title: Text(
                        '${event.actor?.name ?? 'System'} ${event.summary}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: event.conversationTitle == null
                          ? null
                          : Text(
                              event.conversationTitle!,
                              style: const TextStyle(fontSize: 10),
                            ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            time,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          if (event.isTechnical)
                            const Text(
                              'TECHNICAL',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
