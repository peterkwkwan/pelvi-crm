import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../clients/client_format.dart';

/// Create an appointment: date/time + client (+ status).
class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({
    super.key,
    this.clientId,
    this.initialDay,
  });

  /// When set, client is locked to this id.
  final int? clientId;

  /// Optional day seed (defaults to today).
  final DateTime? initialDay;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _day;
  late TimeOfDay _time;
  AppointmentStatus _status = AppointmentStatus.scheduled;
  int? _clientId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialDay ?? DateTime.now();
    _day = DateTime(seed.year, seed.month, seed.day);
    _time = TimeOfDay.fromDateTime(DateTime.now());
    _clientId = widget.clientId;
  }

  DateTime get _startsAt => DateTime(
        _day.year,
        _day.month,
        _day.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _day = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final clientId = _clientId;
    if (clientId == null) return;
    setState(() => _saving = true);
    final db = AppDatabaseProvider.of(context);
    try {
      await db.insertAppointment(
        clientId: clientId,
        startsAt: _startsAt,
        status: _status,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = AppDatabaseProvider.of(context);
    final text = Theme.of(context).textTheme;
    final lockedClient = widget.clientId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('New appointment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(PelviSpace.md),
          children: [
            Text('CLIENT', style: text.labelMedium),
            const SizedBox(height: PelviSpace.xs),
            if (lockedClient)
              FutureBuilder<Client?>(
                future: db.getClient(widget.clientId!),
                builder: (context, snap) {
                  final name = snap.data == null
                      ? '…'
                      : clientDisplayName(snap.data!);
                  return InputDecorator(
                    decoration: const InputDecoration(),
                    child: Text(name, style: text.bodyLarge),
                  );
                },
              )
            else
              StreamBuilder<List<Client>>(
                stream: db.watchClients(),
                builder: (context, snap) {
                  final clients = snap.data ?? const <Client>[];
                  if (clients.isEmpty) {
                    return Text(
                      'Add a client first, then book a visit.',
                      style: text.bodyMedium?.copyWith(
                        color: PelviColors.inkMuted,
                      ),
                    );
                  }
                  return DropdownButtonFormField<int>(
                    initialValue: _clientId,
                    decoration: const InputDecoration(),
                    hint: const Text('Select client'),
                    items: [
                      for (final c in clients)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(clientDisplayName(c)),
                        ),
                    ],
                    onChanged: (id) => setState(() => _clientId = id),
                    validator: (v) => v == null ? 'Pick a client' : null,
                  );
                },
              ),
            const SizedBox(height: PelviSpace.md),
            Text('DATE', style: text.labelMedium),
            const SizedBox(height: PelviSpace.xs),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(
                  '${_day.year.toString().padLeft(4, '0')}-'
                  '${_day.month.toString().padLeft(2, '0')}-'
                  '${_day.day.toString().padLeft(2, '0')}',
                  style: text.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: PelviSpace.md),
            Text('TIME', style: text.labelMedium),
            const SizedBox(height: PelviSpace.xs),
            InkWell(
              onTap: _pickTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.schedule_outlined, size: 18),
                ),
                child: Text(
                  formatApptTime(
                    DateTime(0, 1, 1, _time.hour, _time.minute),
                  ),
                  style: text.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: PelviSpace.md),
            Text('STATUS', style: text.labelMedium),
            const SizedBox(height: PelviSpace.xs),
            DropdownButtonFormField<AppointmentStatus>(
              initialValue: _status,
              decoration: const InputDecoration(),
              items: [
                for (final s in AppointmentStatus.values)
                  DropdownMenuItem(
                    value: s,
                    child: Text(appointmentStatusLabel(s)),
                  ),
              ],
              onChanged: (s) {
                if (s != null) setState(() => _status = s);
              },
            ),
            const SizedBox(height: PelviSpace.lg),
            FilledButton(
              onPressed: _saving || _clientId == null ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PelviColors.inkInverse,
                      ),
                    )
                  : const Text('Save appointment'),
            ),
          ],
        ),
      ),
    );
  }
}
