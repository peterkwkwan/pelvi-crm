import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../widgets/empty_state.dart';
import '../placeholders/stub_screens.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabPlaceholderScaffold(
      title: 'Today',
      emptyTitle: 'Nothing on today',
      emptyBody:
          'Your agenda will show here — appointments and open SOAP drafts for the day.',
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: Container(
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
        ),
        const SizedBox(width: PelviSpace.sm),
      ],
      trailingWell: DashedEmptyWell(
        message: 'No appointments scheduled for today.',
        ctaLabel: 'Add appointment',
        onCta: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const StubScreen(
                title: 'New appointment',
                body: 'Appointment create form comes in the next slice.',
              ),
            ),
          );
        },
      ),
    );
  }
}
