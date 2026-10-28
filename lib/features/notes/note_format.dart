import '../../data/database.dart';

String noteStatusLabel(NoteStatus status) {
  return switch (status) {
    NoteStatus.draft => 'Draft',
    NoteStatus.finalized => 'Final',
  };
}

String formatNoteDate(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
