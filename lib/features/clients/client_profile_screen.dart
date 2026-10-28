import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/empty_state.dart';
import '../appointments/appointment_form_screen.dart';
import 'client_form_screen.dart';
import 'client_format.dart';

class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({super.key, required this.clientId});

  final int clientId;

  @override
  Widget build(BuildContext context) {
    final db = AppDatabaseProvider.of(context);

    return StreamBuilder<Client?>(
      stream: db.watchClient(clientId),
      builder: (context, snap) {
        final client = snap.data;
        if (snap.connectionState == ConnectionState.waiting && client == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: PelviColors.pink700),
            ),
          );
        }
        if (client == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Client')),
            body: QuietEmptyState(
              title: 'Client gone',
              body: 'This profile is no longer in the local database.',
              primaryLabel: 'Back',
              onPrimary: () => Navigator.of(context).pop(),
            ),
          );
        }

        final text = Theme.of(context).textTheme;
        final name = clientDisplayName(client);

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ClientFormScreen(existing: client),
                    ),
                  );
                },
                child: const Text('Edit'),
              ),
            ],
          ),
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(PelviSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.headlineMedium),
                    if (client.phone != null && client.phone!.isNotEmpty) ...[
                      const SizedBox(height: PelviSpace.xs),
                      Text(
                        client.phone!,
                        style: text.bodyMedium?.copyWith(
                          color: PelviColors.inkMuted,
                        ),
                      ),
                    ],
                    if (client.email != null && client.email!.isNotEmpty) ...[
                      const SizedBox(height: PelviSpace.xs),
                      Text(
                        client.email!,
                        style: text.bodyMedium?.copyWith(
                          color: PelviColors.inkMuted,
                        ),
                      ),
                    ],
                    if (client.emergencyContact != null &&
                        client.emergencyContact!.isNotEmpty) ...[
                      const SizedBox(height: PelviSpace.sm),
                      Text('EMERGENCY', style: text.labelMedium),
                      const SizedBox(height: PelviSpace.xs),
                      Text(client.emergencyContact!, style: text.bodyMedium),
                    ],
                    const SizedBox(height: PelviSpace.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AppointmentFormScreen(
                                clientId: client.id,
                              ),
                            ),
                          );
                        },
                        child: const Text('New appointment'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PelviSpace.md,
                  PelviSpace.md,
                  PelviSpace.md,
                  PelviSpace.sm,
                ),
                child: Text('APPOINTMENTS', style: text.labelMedium),
              ),
              StreamBuilder<List<Appointment>>(
                stream: db.watchAppointmentsForClient(clientId),
                builder: (context, apptSnap) {
                  final appts = apptSnap.data ?? const <Appointment>[];
                  if (appts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        PelviSpace.md,
                        0,
                        PelviSpace.md,
                        PelviSpace.lg,
                      ),
                      child: DashedEmptyWell(
                        message: 'No appointments yet for this client.',
                        ctaLabel: 'Book visit',
                        onCta: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AppointmentFormScreen(
                                clientId: client.id,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < appts.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _AppointmentRow(appointment: appts[i]),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PelviSpace.md,
        vertical: PelviSpace.sm + 4,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatApptWhen(appointment.startsAt),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              appointmentStatusLabel(appointment.status),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
