import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelvi_crm/app.dart';
import 'package:pelvi_crm/data/database.dart';
import 'package:pelvi_crm/data/database_provider.dart';
import 'package:pelvi_crm/data/sync_stub.dart';
import 'package:pelvi_crm/features/appointments/appointment_form_screen.dart';
import 'package:pelvi_crm/features/notes/note_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nextWholeHour rounds past the hour, keeps exact hour', () {
    expect(
      nextWholeHour(DateTime(2026, 10, 28, 12, 48)),
      const TimeOfDay(hour: 13, minute: 0),
    );
    expect(
      nextWholeHour(DateTime(2026, 10, 28, 9, 0)),
      const TimeOfDay(hour: 9, minute: 0),
    );
    expect(
      nextWholeHour(DateTime(2026, 10, 28, 23, 1)),
      const TimeOfDay(hour: 0, minute: 0),
    );
  });

  testWidgets('first-run shows when practitioner name missing', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(PelviApp(database: db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Pelvi'), findsOneWidget);
    expect(find.text('What should we call your practice?'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('shell opens when practitioner name is set', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.setPractitionerName('Test Clinic');

    await tester.pumpWidget(PelviApp(database: db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Clients'), findsWidgets);
    expect(find.text('More'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  test('client and appointment round-trip in memory db', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final clientId = await db.insertClient(
      firstName: 'Ada',
      lastName: 'Lovelace',
      phone: '123',
      email: 'ada@example.com',
    );
    final client = await db.getClient(clientId);
    expect(client?.firstName, 'Ada');
    expect(client?.phone, '123');

    final starts = DateTime(2026, 10, 28, 9, 30);
    await db.insertAppointment(clientId: clientId, startsAt: starts);

    final forClient = await db.watchAppointmentsForClient(clientId).first;
    expect(forClient, hasLength(1));
    expect(forClient.first.status, AppointmentStatus.scheduled);

    final today = await db.watchAppointmentsWithClientOnDay(starts).first;
    expect(today, hasLength(1));
    expect(today.first.client.lastName, 'Lovelace');
  });

  test('SOAP draft finalize locks fields; addendum and copy last', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final clientId = await db.insertClient(
      firstName: 'Ada',
      lastName: 'Lovelace',
    );
    final appt1 = await db.insertAppointment(
      clientId: clientId,
      startsAt: DateTime(2026, 10, 1, 10),
    );
    final appt2 = await db.insertAppointment(
      clientId: clientId,
      startsAt: DateTime(2026, 10, 28, 10),
    );

    final first = await db.getOrCreateNoteForAppointment(
      appointmentId: appt1,
      clientId: clientId,
      noteDate: DateTime(2026, 10, 1, 10),
    );
    await db.updateNoteDraft(
      id: first.id,
      subjective: 'pain',
      objective: 'ROM limited',
      assessment: 'strain',
      plan: 'ice',
    );
    expect(await db.finalizeNote(first.id), isTrue);

    // Finalized: draft write is a no-op.
    await db.updateNoteDraft(
      id: first.id,
      subjective: 'rewritten',
      objective: 'x',
      assessment: 'x',
      plan: 'x',
    );
    final locked = await db.getNote(first.id);
    expect(locked?.status, NoteStatus.finalized);
    expect(locked?.subjective, 'pain');

    await db.updateNoteAddendum(id: first.id, addendum: 'follow-up ok');
    expect((await db.getNote(first.id))?.addendum, 'follow-up ok');

    final second = await db.getOrCreateNoteForAppointment(
      appointmentId: appt2,
      clientId: clientId,
      noteDate: DateTime(2026, 10, 28, 10),
    );
    expect(second.status, NoteStatus.draft);
    expect(
      await db.copySoapIntoDraft(targetId: second.id, source: locked!),
      isTrue,
    );
    final copied = await db.getNote(second.id);
    expect(copied?.subjective, 'pain');
    expect(copied?.plan, 'ice');

    // Same appointment reopens the same note.
    final again = await db.getOrCreateNoteForAppointment(
      appointmentId: appt2,
      clientId: clientId,
    );
    expect(again.id, second.id);

    final history = await db.watchNotesForClient(clientId).first;
    expect(history, hasLength(2));
  });

  testWidgets('note editor leaves loading after open', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final clientId = await db.insertClient(
      firstName: 'Peter',
      lastName: 'Kwan',
    );
    final apptId = await db.insertAppointment(
      clientId: clientId,
      startsAt: DateTime(2026, 10, 28, 13, 50),
    );
    final note = await db.getOrCreateNoteForAppointment(
      appointmentId: apptId,
      clientId: clientId,
      noteDate: DateTime(2026, 10, 28, 13, 50),
    );

    await tester.pumpWidget(
      AppDatabaseProvider(
        database: db,
        syncEngine: const StubSyncEngine(),
        child: MaterialApp(
          home: NoteEditorScreen(noteId: note.id),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Peter Kwan'), findsOneWidget);
    expect(find.text('Copy last note'), findsOneWidget);
  });
}
