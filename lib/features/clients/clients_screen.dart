import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/empty_state.dart';
import 'client_form_screen.dart';
import 'client_format.dart';
import 'client_profile_screen.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  void _openNew(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ClientFormScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = AppDatabaseProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            tooltip: 'Add client',
            onPressed: () => _openNew(context),
            style: IconButton.styleFrom(
              foregroundColor: PelviColors.pink700,
            ),
            icon: const Icon(Icons.person_add_outlined),
          ),
          const SizedBox(width: PelviSpace.sm),
        ],
      ),
      body: StreamBuilder<List<Client>>(
        stream: db.watchClients(),
        builder: (context, snap) {
          final clients = snap.data;
          if (clients == null) {
            return const Center(
              child: CircularProgressIndicator(color: PelviColors.pink700),
            );
          }
          if (clients.isEmpty) {
            return Column(
              children: [
                const Expanded(
                  child: QuietEmptyState(
                    title: 'No clients yet',
                    body:
                        'Add your first patient to start booking visits and writing SOAP notes.',
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
                    message: 'Your client list will appear here.',
                    ctaLabel: 'Add client',
                    onCta: () => _openNew(context),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            itemCount: clients.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final c = clients[index];
              final meta = [
                if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
                if (c.email != null && c.email!.isNotEmpty) c.email!,
              ].join(' · ');
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ClientProfileScreen(clientId: c.id),
                    ),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                clientDisplayName(c),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              if (meta.isNotEmpty)
                                Text(
                                  meta,
                                  style:
                                      Theme.of(context).textTheme.labelMedium,
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: PelviColors.inkMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
