import 'package:flutter/material.dart';

import '../../widgets/empty_state.dart';
import '../placeholders/stub_screens.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabPlaceholderScaffold(
      title: 'Calendar',
      emptyTitle: 'Month view soon',
      emptyBody:
          'Month grid with patient counts and day lists will land after clients & appointments.',
      trailingWell: DashedEmptyWell(
        message: 'Tap + to book an appointment once the calendar is live.',
      ),
    );
  }
}
