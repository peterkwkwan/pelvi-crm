import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/empty_state.dart';
import 'client_form_screen.dart';
import 'client_format.dart';
import 'client_profile_screen.dart';

enum _ClientsFilter { all, due }

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _query = '';
  _ClientsFilter _filter = _ClientsFilter.all;

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
    final now = DateTime.now();

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

          return StreamBuilder<List<RecallDueEntry>>(
            stream: db.watchRecallDueClients(),
            builder: (context, dueSnap) {
              final due = dueSnap.data ?? const <RecallDueEntry>[];
              final dueById = {for (final e in due) e.client.id: e};
              final searching = _query.trim().isNotEmpty;

              var listed = filterClients(clients, _query);
              if (_filter == _ClientsFilter.due) {
                listed = [
                  for (final c in listed)
                    if (dueById.containsKey(c.id)) c,
                ];
                // Oldest last-seen first when showing due.
                listed.sort(
                  (a, b) => dueById[a.id]!
                      .lastSeen
                      .compareTo(dueById[b.id]!.lastSeen),
                );
              }

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
                          borderSide:
                              const BorderSide(color: PelviColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PelviRadius.md),
                          borderSide:
                              const BorderSide(color: PelviColors.border),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PelviSpace.md,
                      0,
                      PelviSpace.md,
                      PelviSpace.sm,
                    ),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filter == _ClientsFilter.all,
                          onTap: () =>
                              setState(() => _filter = _ClientsFilter.all),
                        ),
                        const SizedBox(width: PelviSpace.sm),
                        _FilterChip(
                          label: due.isEmpty
                              ? 'Due'
                              : 'Due (${due.length})',
                          selected: _filter == _ClientsFilter.due,
                          onTap: () =>
                              setState(() => _filter = _ClientsFilter.due),
                        ),
                      ],
                    ),
                  ),
                  if (!searching && _filter == _ClientsFilter.all)
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
                  if (listed.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          _filter == _ClientsFilter.due && !searching
                              ? 'No recalls due.'
                              : 'No matches.',
                          style: text.bodyMedium?.copyWith(
                            color: PelviColors.inkMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: listed.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final c = listed[index];
                          final dueEntry = dueById[c.id];
                          final caption = dueEntry == null
                              ? null
                              : formatLastSeenCaption(dueEntry.lastSeen, now);
                          return _ClientRow(
                            client: c,
                            dueCaption: _filter == _ClientsFilter.due
                                ? caption
                                : null,
                            onTap: () => _openProfile(c.id),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? PelviColors.pink700 : PelviColors.ink,
        side: BorderSide(
          color: selected ? PelviColors.pink700 : PelviColors.border,
        ),
        backgroundColor: selected ? PelviColors.pink50 : PelviColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: PelviSpace.md),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PelviRadius.md),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? PelviColors.pink700 : PelviColors.ink,
            ),
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
        // Two chip rows (36) + gap; ClipRect hides anything that would need a 3rd.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PelviSpace.md),
          child: ClipRect(
            child: SizedBox(
              height: 36 * 2 + PelviSpace.sm,
              width: double.infinity,
              child: Align(
                alignment: Alignment.topLeft,
                child: Wrap(
                  spacing: PelviSpace.sm,
                  runSpacing: PelviSpace.sm,
                  children: [
                    for (final c in clients)
                      OutlinedButton(
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
                            borderRadius:
                                BorderRadius.circular(PelviRadius.md),
                          ),
                        ),
                        child: Text(
                          clientDisplayName(c),
                          style: text.labelLarge,
                        ),
                      ),
                  ],
                ),
              ),
            ),
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
    this.dueCaption,
  });

  final Client client;
  final VoidCallback onTap;
  final String? dueCaption;

  @override
  Widget build(BuildContext context) {
    final meta = dueCaption ??
        [
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
