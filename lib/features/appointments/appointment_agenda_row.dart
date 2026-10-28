import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/theme.dart';
import '../clients/client_format.dart';
import '../notes/open_note.dart';

/// Today / Calendar day-list row: time · client · status → open note.
class AppointmentAgendaRow extends StatelessWidget {
  const AppointmentAgendaRow({
    super.key,
    required this.appointment,
    required this.client,
    this.past = false,
  });

  final Appointment appointment;
  final Client client;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final ink = past ? PelviColors.inkMuted : PelviColors.ink;
    final decoration = past ? TextDecoration.lineThrough : TextDecoration.none;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: () {
        openNoteForAppointment(
          context,
          appointmentId: appointment.id,
          clientId: client.id,
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
              SizedBox(
                width: 56,
                child: Text(
                  formatApptTime(appointment.startsAt),
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ink,
                    decoration: decoration,
                    decorationColor: ink,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      clientDisplayName(client),
                      style: text.labelLarge?.copyWith(
                        color: ink,
                        decoration: decoration,
                        decorationColor: ink,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        style: text.labelMedium?.copyWith(
                          color: PelviColors.inkMuted,
                          decoration: decoration,
                          decorationColor: PelviColors.inkMuted,
                        ),
                        children: [
                          TextSpan(
                            text: appointmentStatusLabel(appointment.status),
                            style: TextStyle(
                              color: past
                                  ? PelviColors.inkMuted
                                  : appointmentStatusColor(appointment.status),
                              decoration: decoration,
                              decorationColor: PelviColors.inkMuted,
                            ),
                          ),
                          const TextSpan(text: ' · Note'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.notes_outlined,
                color: past ? PelviColors.inkMuted : PelviColors.purple700,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
