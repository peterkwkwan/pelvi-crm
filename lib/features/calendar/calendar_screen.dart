import 'package:flutter/material.dart';

import '../../widgets/empty_state.dart';
import '../appointments/appointment_form_screen.dart';
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
        message: 'No appointments on the calendar yet.',
        ctaLabel: 'Add appointment',
        onCta: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AppointmentFormScreen(),
            ),
          );
        },
      ),
    );
  }
}
