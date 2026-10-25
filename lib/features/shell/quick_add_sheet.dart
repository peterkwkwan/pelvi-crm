import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../placeholders/stub_screens.dart';

/// FAB quick-add sheet: Client / Appointment / Note.
Future<void> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: PelviColors.surface,
    barrierColor: PelviColors.overlay,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(PelviRadius.lg)),
    ),
    builder: (context) => const QuickAddSheet(),
  );
}

class QuickAddSheet extends StatelessWidget {
  const QuickAddSheet({super.key});

  void _openStub(BuildContext context, String title, String body) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StubScreen(title: title, body: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PelviSpace.md,
          PelviSpace.sm,
          PelviSpace.md,
          PelviSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: PelviSpace.md),
            Text(
              'Quick add',
              style: text.titleLarge,
            ),
            const SizedBox(height: PelviSpace.xs),
            Text(
              'Start a client, appointment, or SOAP note.',
              style: text.bodyMedium?.copyWith(color: PelviColors.inkMuted),
            ),
            const SizedBox(height: PelviSpace.md),
            const Divider(height: 1),
            _QuickAddRow(
              icon: Icons.person_add_outlined,
              title: 'Client',
              subtitle: 'Add a new patient profile',
              onTap: () => _openStub(
                context,
                'New client',
                'Client create form comes in the next slice.',
              ),
            ),
            const Divider(height: 1),
            _QuickAddRow(
              icon: Icons.event_outlined,
              title: 'Appointment',
              subtitle: 'Book a visit on the calendar',
              onTap: () => _openStub(
                context,
                'New appointment',
                'Appointment create form comes in the next slice.',
              ),
            ),
            const Divider(height: 1),
            _QuickAddRow(
              icon: Icons.notes_outlined,
              title: 'Note',
              subtitle: 'Start a SOAP draft',
              onTap: () => _openStub(
                context,
                'New note',
                'SOAP editor comes after clients & appointments.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: PelviColors.surfaceMuted,
      highlightColor: PelviColors.surfaceMuted,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: PelviSpace.sm + 4,
          horizontal: PelviSpace.xs,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: PelviColors.pink700),
            const SizedBox(width: PelviSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelMedium,
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
    );
  }
}
