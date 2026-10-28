import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/empty_state.dart';
import '../appointments/appointment_form_screen.dart';
import '../notes/note_format.dart';
import '../notes/open_note.dart';
import 'client_form_screen.dart';
import 'client_format.dart';

Future<void> _launchExternal(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _onPhoneTap(BuildContext context, String phone) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Phone'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'call'),
          child: const Text('Phone call'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'whatsapp'),
          child: const Text('WhatsApp'),
        ),
      ],
    ),
  );
  if (choice == null) return;
  if (choice == 'call') {
    await _launchExternal(Uri(scheme: 'tel', path: phone));
  } else {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    await _launchExternal(Uri.parse('https://wa.me/$digits'));
  }
}

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
                padding: const EdgeInsets.fromLTRB(
                  PelviSpace.md,
                  PelviSpace.lg,
                  PelviSpace.md,
                  PelviSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.headlineMedium),
                    if ((client.phone != null && client.phone!.isNotEmpty) ||
                        (client.email != null &&
                            client.email!.isNotEmpty)) ...[
                      const SizedBox(height: PelviSpace.md),
                      if (client.phone != null &&
                          client.phone!.isNotEmpty)
                        _PhoneLink(phone: client.phone!),
                      if (client.email != null &&
                          client.email!.isNotEmpty) ...[
                        if (client.phone != null &&
                            client.phone!.isNotEmpty)
                          const SizedBox(height: PelviSpace.sm),
                        _EmailLink(email: client.email!),
                      ],
                    ],
                    if ((client.emergencyContact != null &&
                            client.emergencyContact!.isNotEmpty) ||
                        (client.emergencyContactPhone != null &&
                            client.emergencyContactPhone!.isNotEmpty)) ...[
                      const SizedBox(height: PelviSpace.lg),
                      const Divider(height: 1),
                      const SizedBox(height: PelviSpace.lg),
                      Text('EMERGENCY', style: text.labelMedium),
                      if (client.emergencyContact != null &&
                          client.emergencyContact!.isNotEmpty) ...[
                        const SizedBox(height: PelviSpace.sm),
                        Text(
                          client.emergencyContact!,
                          style: text.bodyMedium,
                        ),
                      ],
                      if (client.emergencyContactPhone != null &&
                          client.emergencyContactPhone!.isNotEmpty) ...[
                        const SizedBox(height: PelviSpace.sm),
                        _PhoneLink(phone: client.emergencyContactPhone!),
                      ],
                    ],
                    if (client.notes != null && client.notes!.isNotEmpty) ...[
                      const SizedBox(height: PelviSpace.lg),
                      const Divider(height: 1),
                      const SizedBox(height: PelviSpace.lg),
                      Text('NOTES', style: text.labelMedium),
                      const SizedBox(height: PelviSpace.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 96),
                        child: SingleChildScrollView(
                          child: Text(
                            client.notes!,
                            style: text.bodyMedium?.copyWith(
                              color: PelviColors.inkMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: PelviSpace.lg),
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
                        _AppointmentRow(
                          appointment: appts[i],
                          clientId: client.id,
                        ),
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

class _PhoneLink extends StatelessWidget {
  const _PhoneLink({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _onPhoneTap(context, phone),
      child: Row(
        children: [
          const Icon(
            Icons.phone_outlined,
            size: 18,
            color: PelviColors.pink700,
          ),
          const SizedBox(width: PelviSpace.sm),
          Expanded(
            child: Text(
              phone,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PelviColors.pink700,
                    decoration: TextDecoration.underline,
                    decorationColor: PelviColors.pink700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailLink extends StatelessWidget {
  const _EmailLink({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _launchExternal(Uri(scheme: 'mailto', path: email)),
      child: Row(
        children: [
          const Icon(
            Icons.email_outlined,
            size: 18,
            color: PelviColors.inkMuted,
          ),
          const SizedBox(width: PelviSpace.sm),
          Expanded(
            child: Text(
              email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PelviColors.inkMuted,
                    decoration: TextDecoration.underline,
                    decorationColor: PelviColors.inkMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({
    required this.appointment,
    required this.clientId,
  });

  final Appointment appointment;
  final int clientId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        openNoteForAppointment(
          context,
          appointmentId: appointment.id,
          clientId: clientId,
          noteDate: appointment.startsAt,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatApptWhen(appointment.startsAt),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.labelMedium,
                        children: [
                          TextSpan(
                            text: appointmentStatusLabel(appointment.status),
                            style: TextStyle(
                              color:
                                  appointmentStatusColor(appointment.status),
                            ),
                          ),
                          TextSpan(
                            text: ' · Open note',
                            style: TextStyle(color: PelviColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.notes_outlined,
                color: PelviColors.purple700,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
