import 'package:flutter/material.dart';

import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/empty_state.dart';
import '../appointments/appointment_form_screen.dart';
import '../clients/client_format.dart';
import '../clients/client_profile_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  void _openNewAppointment(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentFormScreen(initialDay: DateTime.now()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = AppDatabaseProvider.of(context);
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
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
      ),
      body: StreamBuilder(
        stream: db.watchAppointmentsWithClientOnDay(today),
        builder: (context, snap) {
          final rows = snap.data;
          if (rows == null) {
            return const Center(
              child: CircularProgressIndicator(color: PelviColors.pink700),
            );
          }
          if (rows.isEmpty) {
            return Column(
              children: [
                const Expanded(
                  child: QuietEmptyState(
                    title: 'Nothing on today',
                    body:
                        'Your agenda will show here — appointments and open SOAP drafts for the day.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PelviSpace.md,
                    0,
                    PelviSpace.md,
                    PelviSpace.lg,
                  ),
                  child: DashedEmptyWell(
                    message: 'No appointments scheduled for today.',
                    ctaLabel: 'Add appointment',
                    onCta: () => _openNewAppointment(context),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              final appt = row.appointment;
              final client = row.client;
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ClientProfileScreen(clientId: client.id),
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
                        SizedBox(
                          width: 56,
                          child: Text(
                            formatApptTime(appt.startsAt),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                clientDisplayName(client),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                appointmentStatusLabel(appt.status),
                                style:
                                    Theme.of(context).textTheme.labelMedium,
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
    );
  }
}
