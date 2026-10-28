import 'database.dart';

/// Client past the recall window (or never seen).
class RecallDueEntry {
  const RecallDueEntry({
    required this.client,
    required this.lastSeen,
  });

  final Client client;

  /// Latest non-cancelled appointment or note date; null if never visited.
  final DateTime? lastSeen;
}

/// Last activity = max(non-cancelled appointment.startsAt, note.noteDate).
DateTime? lastSeenForClient({
  required int clientId,
  required List<Appointment> appointments,
  required List<Note> notes,
}) {
  DateTime? last;
  for (final a in appointments) {
    if (a.clientId != clientId) continue;
    if (a.status == AppointmentStatus.cancelled) continue;
    if (last == null || a.startsAt.isAfter(last)) last = a.startsAt;
  }
  for (final n in notes) {
    if (n.clientId != clientId) continue;
    if (last == null || n.noteDate.isAfter(last)) last = n.noteDate;
  }
  return last;
}

/// Pure filter — easy to unit-test without Drift streams.
List<RecallDueEntry> computeRecallDue({
  required List<Client> clients,
  required List<Appointment> appointments,
  required List<Note> notes,
  required int recallDays,
  required DateTime now,
}) {
  final cutoff = now.subtract(Duration(days: recallDays));
  final due = <RecallDueEntry>[];
  for (final c in clients) {
    final last = lastSeenForClient(
      clientId: c.id,
      appointments: appointments,
      notes: notes,
    );
    if (last == null || last.isBefore(cutoff)) {
      due.add(RecallDueEntry(client: c, lastSeen: last));
    }
  }
  due.sort((a, b) {
    final aLast = a.lastSeen;
    final bLast = b.lastSeen;
    if (aLast == null && bLast == null) {
      return a.client.lastName.compareTo(b.client.lastName);
    }
    if (aLast == null) return -1;
    if (bLast == null) return 1;
    return aLast.compareTo(bLast);
  });
  return due;
}

String formatLastSeenCaption(DateTime? lastSeen, DateTime now) {
  if (lastSeen == null) return 'Never seen';
  final days = now.difference(lastSeen).inDays;
  if (days <= 0) return 'Seen today';
  if (days == 1) return 'Last seen 1 day ago';
  return 'Last seen $days days ago';
}
