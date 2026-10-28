import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/empty_state.dart';
import '../appointments/appointment_form_screen.dart';
import '../notes/note_editor_screen.dart';
import '../notes/note_format.dart';
import '../notes/open_note.dart';
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
                    if (client.notes != null && client.notes!.isNotEmpty) ...[
                      const SizedBox(height: PelviSpace.sm),
                      Text('NOTES', style: text.labelMedium),
                      const SizedBox(height: PelviSpace.xs),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 72),
                        child: SingleChildScrollView(
                          child: Text(
                            client.notes!,
                            style: text.bodyMedium,
                          ),
                        ),
                      ),
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
                child: Text('VISIT HISTORY', style: text.labelMedium),
              ),
              StreamBuilder<List<Note>>(
                stream: db.watchNotesForClient(clientId),
                builder: (context, noteSnap) {
                  final notes = noteSnap.data ?? const <Note>[];
                  if (notes.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        PelviSpace.md,
                        0,
                        PelviSpace.md,
                        PelviSpace.md,
                      ),
                      child: Text(
                        'No SOAP notes yet. Open a note from an appointment below.',
                        style: text.bodyMedium?.copyWith(
                          color: PelviColors.inkMuted,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < notes.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _NoteHistoryRow(note: notes[i]),
                      ],
                    ],
                  );
                },
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

class _NoteHistoryRow extends StatelessWidget {
  const _NoteHistoryRow({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NoteEditorScreen(noteId: note.id),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatNoteDate(note.noteDate),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      noteStatusLabel(note.status),
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
                    Text(
                      '${appointmentStatusLabel(appointment.status)} · Open note',
                      style: Theme.of(context).textTheme.labelMedium,
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
