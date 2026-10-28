import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../widgets/empty_state.dart';
import '../appointments/appointment_form_screen.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
<<<<<<< Updated upstream
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
              builder: (_) => const StubScreen(
                title: 'New appointment',
                body: 'Appointment create form comes in the next slice.',
              ),
            ),
          );
        },
=======
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(
        children: [
          const Expanded(
            child: QuietEmptyState(
              title: 'Month view soon',
              body:
                  'Month grid with patient counts and day lists will land after clients & appointments.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PelviSpace.md,
              0,
              PelviSpace.md,
              PelviSpace.lg,
            ),
            child: DashedEmptyWell(
              message: 'Book a visit while the month grid is still stubbed.',
              ctaLabel: 'Add appointment',
              onCta: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppointmentFormScreen(),
                  ),
                );
              },
            ),
          ),
        ],
>>>>>>> Stashed changes
      ),
    );
  }
}
