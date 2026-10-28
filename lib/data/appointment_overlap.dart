/// Effective end when [endsAt] is missing: start + default duration.
DateTime appointmentEffectiveEnd(
  DateTime startsAt,
  DateTime? endsAt,
  int defaultMinutes,
) {
  return endsAt ?? startsAt.add(Duration(minutes: defaultMinutes));
}

/// Half-open intervals [aStart, aEnd) and [bStart, bEnd).
bool appointmentsOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) {
  return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
}

/// Snackbar / dialog copy when save is blocked.
String appointmentConflictCopy({
  required String clientName,
  required DateTime startsAt,
}) {
  final hh = startsAt.hour.toString().padLeft(2, '0');
  final mm = startsAt.minute.toString().padLeft(2, '0');
  return 'Overlaps $clientName at $hh:$mm';
}
