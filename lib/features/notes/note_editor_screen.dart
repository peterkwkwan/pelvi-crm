import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../theme/theme.dart';
import '../clients/client_format.dart';
import 'note_format.dart';

/// SOAP note editor: draft edit → finalize → view-only + addendum.
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
  final _addendum = TextEditingController();

  Note? _note;
  Client? _client;
  Appointment? _appointment;
  bool _loading = true;
  bool _saving = false;
  bool _hydrated = false;
  Timer? _draftDebounce;
  Timer? _addendumDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _addendumDebounce?.cancel();
    _subjective.dispose();
    _objective.dispose();
    _assessment.dispose();
    _plan.dispose();
    _addendum.dispose();
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
        _addendum.text = note.addendum;
        _hydrated = true;
      }
      _loading = false;
    });
  }

  void _scheduleDraftSave() {
    if (_note?.status != NoteStatus.draft) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 400), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final note = _note;
    if (note == null || note.status != NoteStatus.draft) return;
    setState(() => _saving = true);
    final db = AppDatabaseProvider.of(context);
    await db.updateNoteDraft(
      id: note.id,
      subjective: _subjective.text,
      objective: _objective.text,
      assessment: _assessment.text,
      plan: _plan.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
  }

  void _scheduleAddendumSave() {
    if (_note?.status != NoteStatus.finalized) return;
    _addendumDebounce?.cancel();
    _addendumDebounce =
        Timer(const Duration(milliseconds: 400), _saveAddendum);
  }

  Future<void> _saveAddendum() async {
    final note = _note;
    if (note == null || note.status != NoteStatus.finalized) return;
    setState(() => _saving = true);
    final db = AppDatabaseProvider.of(context);
    await db.updateNoteAddendum(id: note.id, addendum: _addendum.text);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _copyLastNote() async {
    final note = _note;
    if (note == null || note.status != NoteStatus.draft) return;
    final db = AppDatabaseProvider.of(context);
    final last = await db.getLastNoteForClient(
      note.clientId,
      exceptNoteId: note.id,
    );
    if (!mounted) return;
    if (last == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No earlier note to copy.')),
      );
      return;
    }
    final ok = await db.copySoapIntoDraft(targetId: note.id, source: last);
    if (!ok || !mounted) return;
    setState(() {
      _subjective.text = last.subjective;
      _objective.text = last.objective;
      _assessment.text = last.assessment;
      _plan.text = last.plan;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied last note into this draft.')),
    );
  }

  Future<void> _finalize() async {
    final note = _note;
    if (note == null || note.status != NoteStatus.draft) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize note?'),
        content: const Text(
          'After finalizing, S/O/A/P become view-only. '
          'You can still add an addendum.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _saveDraft();
    if (!mounted) return;
    final db = AppDatabaseProvider.of(context);
    final ok = await db.finalizeNote(note.id);
    if (!ok || !mounted) return;
    await _load();
  }

  Future<bool> _onWillPop() async {
    _draftDebounce?.cancel();
    _addendumDebounce?.cancel();
    if (_note?.status == NoteStatus.draft) {
      await _saveDraft();
    } else if (_note?.status == NoteStatus.finalized) {
      await _saveAddendum();
    }
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

    final isDraft = note.status == NoteStatus.draft;
    final text = Theme.of(context).textTheme;
    final title = _client == null ? 'SOAP note' : clientDisplayName(_client!);
    final when = _appointment != null
        ? formatApptWhen(_appointment!.startsAt)
        : formatNoteDate(note.noteDate);

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
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: PelviSpace.sm),
                child: Center(
                  child: _StatusChip(status: note.status),
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
            if (isDraft) ...[
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
            ],
            const SizedBox(height: PelviSpace.md),
            _SoapField(
              letter: 'S',
              label: 'Subjective',
              controller: _subjective,
              readOnly: !isDraft,
              onChanged: (_) => _scheduleDraftSave(),
            ),
            const SizedBox(height: PelviSpace.lg),
            _SoapField(
              letter: 'O',
              label: 'Objective',
              controller: _objective,
              readOnly: !isDraft,
              onChanged: (_) => _scheduleDraftSave(),
            ),
            const SizedBox(height: PelviSpace.lg),
            _SoapField(
              letter: 'A',
              label: 'Assessment',
              controller: _assessment,
              readOnly: !isDraft,
              onChanged: (_) => _scheduleDraftSave(),
            ),
            const SizedBox(height: PelviSpace.lg),
            _SoapField(
              letter: 'P',
              label: 'Plan',
              controller: _plan,
              readOnly: !isDraft,
              onChanged: (_) => _scheduleDraftSave(),
            ),
            if (!isDraft) ...[
              const SizedBox(height: PelviSpace.lg),
              Text('ADDENDUM', style: text.labelMedium),
              const SizedBox(height: PelviSpace.xs),
              TextField(
                controller: _addendum,
                minLines: 3,
                maxLines: 8,
                onChanged: (_) => _scheduleAddendumSave(),
                decoration: const InputDecoration(
                  hintText: 'Append a correction or update…',
                ),
              ),
            ],
            if (isDraft) ...[
              const SizedBox(height: PelviSpace.xl),
              FilledButton(
                onPressed: _finalize,
                child: const Text('Finalize'),
              ),
              const SizedBox(height: PelviSpace.sm),
              Text(
                'Drafts save on this device automatically.',
                textAlign: TextAlign.center,
                style: text.labelMedium,
              ),
            ],
            const SizedBox(height: PelviSpace.xxl),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final NoteStatus status;

  @override
  Widget build(BuildContext context) {
    final isDraft = status == NoteStatus.draft;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PelviSpace.sm,
        vertical: PelviSpace.xs,
      ),
      decoration: BoxDecoration(
        color: isDraft ? PelviColors.purple50 : PelviColors.surfaceMuted,
        borderRadius: BorderRadius.circular(PelviRadius.sm),
        border: Border.all(color: PelviColors.border),
      ),
      child: Text(
        noteStatusLabel(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isDraft ? PelviColors.purple700 : PelviColors.success,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SoapField extends StatelessWidget {
  const _SoapField({
    required this.letter,
    required this.label,
    required this.controller,
    required this.readOnly,
    required this.onChanged,
  });

  final String letter;
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PelviColors.purple50,
                borderRadius: BorderRadius.circular(PelviRadius.sm),
                border: Border.all(color: PelviColors.purple700, width: 1.5),
              ),
              child: Text(
                letter,
                style: text.labelLarge?.copyWith(
                  color: PelviColors.purple700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: PelviSpace.sm),
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: PelviColors.purple700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
          readOnly: readOnly,
          minLines: 3,
          maxLines: 8,
          onChanged: readOnly ? null : onChanged,
          style: text.bodyLarge?.copyWith(
            color: readOnly ? PelviColors.ink : PelviColors.ink,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor:
                readOnly ? PelviColors.surfaceMuted : PelviColors.surface,
          ),
        ),
      ],
    );
  }
}
