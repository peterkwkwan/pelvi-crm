import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../clients/client_format.dart';
import '../clients/client_profile_screen.dart';

/// In-app recall list — mirrors the Today bell. Purple badge is reserved for unread.
Future<void> showNotificationsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PelviColors.surface,
    barrierColor: PelviColors.overlay,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(PelviRadius.lg)),
    ),
    builder: (context) => const _NotificationsSheet(),
  );
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    final db = AppDatabaseProvider.of(context);
    final text = Theme.of(context).textTheme;
    final height = MediaQuery.sizeOf(context).height * 0.72;
    final now = DateTime.now();

    return SizedBox(
      height: height,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: PelviSpace.sm),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PelviColors.border,
                  borderRadius: BorderRadius.circular(PelviRadius.full),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PelviSpace.md,
                PelviSpace.md,
                PelviSpace.sm,
                PelviSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Notifications', style: text.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: PelviColors.inkMuted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: PelviColors.chromeBorder),
            Expanded(
              child: StreamBuilder<List<RecallDueEntry>>(
                stream: db.watchRecallDueClients(),
                builder: (context, snap) {
                  final due = snap.data;
                  if (due == null) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: PelviColors.pink700,
                      ),
                    );
                  }
                  if (due.isEmpty) {
                    return Center(
                      child: Text(
                        'No recalls due.',
                        style: text.bodyMedium?.copyWith(
                          color: PelviColors.inkMuted,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: due.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final entry = due[i];
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ClientProfileScreen(
                                clientId: entry.client.id,
                              ),
                            ),
                          );
                        },
                        splashColor: PelviColors.surfaceMuted,
                        highlightColor: PelviColors.surfaceMuted,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: PelviSpace.md,
                            vertical: PelviSpace.sm + 4,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 56),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Recall · ${clientDisplayName(entry.client)}',
                                        style: text.labelLarge,
                                      ),
                                      Text(
                                        formatLastSeenCaption(
                                          entry.lastSeen,
                                          now,
                                        ),
                                        style: text.labelMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: PelviColors.inkMuted,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bell with optional purple unread dot when [dueCount] > 0.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    required this.dueCount,
    required this.onPressed,
  });

  final int dueCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: onPressed,
      icon: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: PelviColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_outlined,
                size: 20,
                color: PelviColors.inkMuted,
              ),
            ),
            if (dueCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: PelviColors.purple700,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
