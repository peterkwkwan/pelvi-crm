import 'package:flutter/material.dart';

import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/picker_sheet.dart';
import '../placeholders/stub_screens.dart';

const _recallDayChoices = <int>[14, 21, 30, 45, 60, 90];

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _editRecallWindow(BuildContext context) async {
    final db = AppDatabaseProvider.of(context);
    final current = await db.getRecallDays();
    if (!context.mounted) return;
    final picked = await showPelviPickerSheet<int>(
      context: context,
      title: 'Recall window',
      selected: current,
      options: [
        for (final d in _recallDayChoices)
          PelviPickerOption(value: d, label: '$d days'),
      ],
    );
    if (picked == null) return;
    await db.setRecallDays(picked);
  }

  @override
  Widget build(BuildContext context) {
    final db = AppDatabaseProvider.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: ListView(
        padding: const EdgeInsets.all(PelviSpace.md),
        children: [
          FutureBuilder<String?>(
            future: db.getPractitionerName(),
            builder: (context, snap) {
              final name = snap.data?.trim();
              return _SettingsBlock(
                children: [
                  _SettingsField(
                    label: 'PRACTITIONER',
                    value: (name == null || name.isEmpty) ? 'Not set' : name,
                  ),
                  const Divider(height: 1),
                  StreamBuilder<int>(
                    stream: db.watchRecallDays(),
                    builder: (context, recallSnap) {
                      final days = recallSnap.data ?? 30;
                      return _TappableRow(
                        title: 'Recall window',
                        subtitle: '$days days · clients with no visit in window',
                        onTap: () => _editRecallWindow(context),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: PelviSpace.lg),
          _SettingsBlock(
            children: [
              _TappableRow(
                title: 'Settings',
                subtitle: 'Hours, timezone, notifications',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StubScreen(
                        title: 'Settings',
                        body: 'Full settings arrive with the account slice.',
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _TappableRow(
                title: 'Export / backup',
                subtitle: 'Local JSON export (coming soon)',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StubScreen(
                        title: 'Export',
                        body: 'Backup export is planned after core SOAP flows.',
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _TappableRow(
                title: 'Account & sync',
                subtitle: 'Local-first · sync stub idle',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StubScreen(
                        title: 'Account',
                        body: 'Auth and cloud sync are stubbed for this scaffold.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsBlock extends StatelessWidget {
  const _SettingsBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PelviColors.surface,
        borderRadius: BorderRadius.circular(PelviRadius.md),
        border: Border.all(color: PelviColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PelviSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  const _SettingsField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PelviSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: PelviSpace.xs),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _TappableRow extends StatelessWidget {
  const _TappableRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

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
        padding: const EdgeInsets.symmetric(vertical: PelviSpace.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
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
