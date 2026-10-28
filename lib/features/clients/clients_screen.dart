import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/empty_state.dart';
import 'client_form_screen.dart';
import 'client_format.dart';
import 'client_profile_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _query = '';

  void _openNew() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ClientFormScreen(),
      ),
    );
  }

  void _openProfile(int clientId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientProfileScreen(clientId: clientId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = AppDatabaseProvider.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            tooltip: 'Add client',
            onPressed: _openNew,
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
                    onCta: _openNew,
                  ),
                ),
              ],
            );
          }

          final filtered = filterClients(clients, _query);
          final searching = _query.trim().isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PelviSpace.md,
                  PelviSpace.md,
                  PelviSpace.md,
                  PelviSpace.sm,
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search name, phone, or email',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: PelviColors.inkMuted,
                    ),
                    filled: true,
                    fillColor: PelviColors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PelviRadius.md),
                      borderSide: const BorderSide(color: PelviColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PelviRadius.md),
                      borderSide: const BorderSide(color: PelviColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PelviRadius.md),
                      borderSide: const BorderSide(
                        color: PelviColors.pink700,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              if (!searching)
                StreamBuilder<List<int>>(
                  stream: db.watchRecentClientIds(),
                  builder: (context, recentSnap) {
                    final recent = clientsInIdOrder(
                      clients,
                      recentSnap.data ?? const [],
                    );
                    if (recent.isEmpty) return const SizedBox.shrink();
                    return _RecentStrip(
                      clients: recent,
                      onTap: _openProfile,
                    );
                  },
                ),
              const Divider(height: 1, color: PelviColors.chromeBorder),
              if (filtered.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No matches.',
                      style: text.bodyMedium?.copyWith(
                        color: PelviColors.inkMuted,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      return _ClientRow(
                        client: c,
                        onTap: () => _openProfile(c.id),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RecentStrip extends StatelessWidget {
  const _RecentStrip({
    required this.clients,
    required this.onTap,
  });

  final List<Client> clients;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PelviSpace.md,
            PelviSpace.sm,
            PelviSpace.md,
            PelviSpace.sm,
          ),
          child: Text('RECENT', style: text.labelMedium),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: PelviSpace.md),
            itemCount: clients.length,
            separatorBuilder: (_, __) => const SizedBox(width: PelviSpace.sm),
            itemBuilder: (context, index) {
              final c = clients[index];
              return OutlinedButton(
                onPressed: () => onTap(c.id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PelviColors.ink,
                  side: const BorderSide(color: PelviColors.border),
                  backgroundColor: PelviColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: PelviSpace.md,
                  ),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PelviRadius.md),
                  ),
                ),
                child: Text(
                  clientDisplayName(c),
                  style: text.labelLarge,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: PelviSpace.md),
      ],
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.client,
    required this.onTap,
  });

  final Client client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (client.phone != null && client.phone!.isNotEmpty) client.phone!,
      if (client.email != null && client.email!.isNotEmpty) client.email!,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
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
                      clientDisplayName(client),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: Theme.of(context).textTheme.labelMedium,
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
  }
}
