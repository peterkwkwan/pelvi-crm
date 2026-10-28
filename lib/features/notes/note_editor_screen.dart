import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/show_snack.dart';
import '../clients/client_format.dart';
import 'note_format.dart';

/// Always-editable SOAP note editor with autosave.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});

  final int noteId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _subjective = TextEditingController();
  final _objective = TextEditingController();
  final _assessment = TextEditingController();
  final _plan = TextEditingController();

  Note? _note;
  Client? _client;
  Appointment? _appointment;
  bool _loading = true;
  bool _saving = false;
  bool _hydrated = false;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    // of() depends on InheritedWidget — illegal during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _subjective.dispose();
    _objective.dispose();
    _assessment.dispose();
    _plan.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = AppDatabaseProvider.of(context);
    final note = await db.getNote(widget.noteId);
    if (note == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final client = await db.getClient(note.clientId);
    final appt = note.appointmentId == null
        ? null
        : await db.getAppointment(note.appointmentId!);
    if (!mounted) return;
    setState(() {
      _note = note;
      _client = client;
      _appointment = appt;
      if (!_hydrated) {
        _subjective.text = note.subjective;
        _objective.text = note.objective;
        _assessment.text = note.assessment;
        _plan.text = note.plan;
        _hydrated = true;
      }
      _loading = false;
    });
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    final note = _note;
    if (note == null) return;
    setState(() => _saving = true);
    final db = AppDatabaseProvider.of(context);
    await db.updateNoteSoap(
      id: note.id,
      subjective: _subjective.text,
      objective: _objective.text,
      assessment: _assessment.text,
      plan: _plan.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _copyLastNote() async {
    final note = _note;
    if (note == null) return;
    final db = AppDatabaseProvider.of(context);
    final last = await db.getLastNoteForClient(
      note.clientId,
      exceptNoteId: note.id,
    );
    if (!mounted) return;
    if (last == null) {
      showPelviSnackBar(context, 'No earlier note to copy.');
      return;
    }
    final ok = await db.copySoapIntoNote(targetId: note.id, source: last);
    if (!ok || !mounted) return;
    setState(() {
      _subjective.text = last.subjective;
      _objective.text = last.objective;
      _assessment.text = last.assessment;
      _plan.text = last.plan;
    });
    showPelviSnackBar(context, 'Copied last note.');
  }

  Future<bool> _onWillPop() async {
    _saveDebounce?.cancel();
    await _save();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: PelviColors.pink700),
        ),
      );
    }
    final note = _note;
    if (note == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: const Center(child: Text('Note not found.')),
      );
    }

    final text = Theme.of(context).textTheme;
    final title = _client == null ? 'SOAP note' : clientDisplayName(_client!);
    final when = formatNoteDate(_appointment?.startsAt ?? note.noteDate);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _onWillPop();
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: PelviSpace.md),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PelviColors.pink700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(PelviSpace.md),
          children: [
            Text(
              when,
              style: text.bodyMedium?.copyWith(color: PelviColors.inkMuted),
            ),
            const SizedBox(height: PelviSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _copyLastNote,
                style: TextButton.styleFrom(
                  foregroundColor: PelviColors.purple700,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Copy last note'),
              ),
            ),
            const SizedBox(height: PelviSpace.md),
            _SoapField(
              icon: Icons.hearing_outlined,
              label: 'Subjective',
              controller: _subjective,
              onChanged: (_) => _scheduleSave(),
            ),
            const SizedBox(height: PelviSpace.lg),
            _SoapField(
              icon: Icons.visibility_outlined,
              label: 'Objective',
              controller: _objective,
              onChanged: (_) => _scheduleSave(),
            ),
            const SizedBox(height: PelviSpace.lg),
            _SoapField(
              icon: Icons.psychology_outlined,
              label: 'Assessment',
              controller: _assessment,
              onChanged: (_) => _scheduleSave(),
            ),
            const SizedBox(height: PelviSpace.lg),
            _SoapField(
              icon: Icons.checklist_rtl,
              label: 'Plan',
              controller: _plan,
              onChanged: (_) => _scheduleSave(),
            ),
            const SizedBox(height: PelviSpace.md),
            Text(
              'Saves on this device automatically.',
              textAlign: TextAlign.center,
              style: text.labelMedium,
            ),
            const SizedBox(height: PelviSpace.xxl),
          ],
        ),
      ),
    );
  }
}

class _SoapField extends StatelessWidget {
  const _SoapField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: PelviColors.purple700),
            const SizedBox(width: PelviSpace.sm),
            Text(
              label.toUpperCase(),
              style: text.labelMedium?.copyWith(
                color: PelviColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: PelviSpace.sm),
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 8,
          onChanged: onChanged,
          style: text.bodyLarge?.copyWith(color: PelviColors.ink),
          decoration: const InputDecoration(
            filled: true,
            fillColor: PelviColors.surface,
          ),
        ),
      ],
    );
  }
}
