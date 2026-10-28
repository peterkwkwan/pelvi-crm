/// Weekday – day – year, e.g. `Wednesday – 28 – 2026`.
String formatNoteDate(DateTime dt) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return '${weekdays[dt.weekday - 1]} – ${dt.day} – ${dt.year}';
}
