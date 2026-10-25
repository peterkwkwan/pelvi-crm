import 'package:flutter/material.dart';

import '../../widgets/empty_state.dart';
import '../placeholders/stub_screens.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabPlaceholderScaffold(
      title: 'Clients',
      emptyTitle: 'No clients yet',
      emptyBody:
          'Add your first patient to start booking visits and writing SOAP notes.',
      trailingWell: DashedEmptyWell(
        message: 'Your client list will appear here.',
        ctaLabel: 'Add client',
        onCta: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const StubScreen(
                title: 'New client',
                body: 'Client create form comes in the next slice.',
              ),
            ),
          );
        },
      ),
    );
  }
}
