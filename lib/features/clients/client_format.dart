import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/colors.dart';

String clientDisplayName(Client c) => '${c.firstName} ${c.lastName}'.trim();

String appointmentStatusLabel(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.scheduled => 'Scheduled',
    AppointmentStatus.completed => 'Completed',
    AppointmentStatus.cancelled => 'Cancelled',
    AppointmentStatus.noShow => 'No-show',
  };
}

/// Status word color only — light/dark pink, purple, muted.
Color appointmentStatusColor(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.scheduled => PelviColors.pink400,
    AppointmentStatus.completed => PelviColors.pink700,
    AppointmentStatus.cancelled => PelviColors.inkMuted,
    AppointmentStatus.noShow => PelviColors.purple700,
  };
}

String formatApptWhen(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d · $hh:$mm';
}

String formatApptTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
