import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelvi_crm/app.dart';
import 'package:pelvi_crm/data/appointment_overlap.dart';
import 'package:pelvi_crm/data/database.dart';
import 'package:pelvi_crm/data/database_provider.dart';
import 'package:pelvi_crm/data/sync_stub.dart';
import 'package:pelvi_crm/features/appointments/appointment_form_screen.dart';
import 'package:pelvi_crm/features/calendar/calendar_screen.dart';
import 'package:pelvi_crm/features/clients/client_format.dart';
import 'package:pelvi_crm/features/clients/clients_screen.dart';
import 'package:pelvi_crm/features/notes/note_editor_screen.dart';
import 'package:pelvi_crm/features/notes/note_format.dart';
import 'package:pelvi_crm/features/notes/soap_dictation.dart';
import 'package:pelvi_crm/widgets/show_snack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('top snack slot grows when conflict copy wraps', (tester) async {
    const message = 'Overlapping appointment: Peter Kwan at 15:00';
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(title: const Text('New appointment')),
              body: Center(
                child: TextButton(
                  onPressed: () => showPelviSnackBar(context, message),
                  child: const Text('Show'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    final margin = snack.margin! as EdgeInsets;
    final slot = 640 - margin.top - margin.bottom;
    // Old helper hard-capped at 56 and clipped the time on wrap.
    expect(slot, greaterThan(56));
    expect(find.text(message), findsOneWidget);
  });

  test('formatNoteDate is EEE, d MMM yyyy', () {
    expect(
      formatNoteDate(DateTime(2026, 10, 28)),
      'Wed, 28 Oct 2026',
    );
  });

  test('appendSoapTranscript joins with newline', () {
    expect(appendSoapTranscript('', '  pain on stairs  '), 'pain on stairs');
    expect(appendSoapTranscript('Sx: LBP', 'worse AM'), 'Sx: LBP\nworse AM');
    expect(appendSoapTranscript('keep', '  '), 'keep');
  });


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

  test('appointment overlap uses default duration when end missing', () {
    final aStart = DateTime(2026, 10, 28, 9);
    final aEnd = appointmentEffectiveEnd(aStart, null, 60);
    final bStart = DateTime(2026, 10, 28, 9, 30);
    final bEnd = appointmentEffectiveEnd(bStart, null, 60);
    expect(appointmentsOverlap(aStart, aEnd, bStart, bEnd), isTrue);
    expect(
      appointmentsOverlap(
        aStart,
        aEnd,
        DateTime(2026, 10, 28, 10),
        DateTime(2026, 10, 28, 11),
      ),
      isFalse,
    );
    expect(
      appointmentConflictCopy(
        clientName: 'Ada Lovelace',
        startsAt: aStart,
      ),
      'Overlapping appointment: Ada Lovelace at 09:00',
    );
  });

  test('insertAppointment blocks overlapping slot', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.ensureDefaults();

    final a = await db.insertClient(firstName: 'Ada', lastName: 'Lovelace');
    final b = await db.insertClient(firstName: 'Grace', lastName: 'Hopper');
    await db.insertAppointment(
      clientId: a,
      startsAt: DateTime(2026, 10, 28, 9),
    );

    await expectLater(
      db.insertAppointment(
        clientId: b,
        startsAt: DateTime(2026, 10, 28, 9, 30),
      ),
      throwsA(isA<AppointmentConflictException>()),
    );

    // Same start after move still blocked; update of self ok.
    final id = await db.insertAppointment(
      clientId: b,
      startsAt: DateTime(2026, 10, 28, 11),
    );
    await expectLater(
      db.updateAppointment(
        id: id,
        startsAt: DateTime(2026, 10, 28, 9, 15),
      ),
      throwsA(isA<AppointmentConflictException>()),
    );
    expect(
      await db.updateAppointment(
        id: id,
        startsAt: DateTime(2026, 10, 28, 11),
      ),
      isTrue,
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
      emergencyContact: 'Lord Byron',
      emergencyContactPhone: '555',
      notes: 'prefers mornings',
    );
    final client = await db.getClient(clientId);
    expect(client?.firstName, 'Ada');
    expect(client?.phone, '123');
    expect(client?.emergencyContact, 'Lord Byron');
    expect(client?.emergencyContactPhone, '555');
    expect(client?.notes, 'prefers mornings');

    await db.updateClient(
      id: clientId,
      firstName: 'Ada',
      lastName: 'Lovelace',
      phone: '123',
      email: 'ada@example.com',
      emergencyContact: 'Lord Byron',
      emergencyContactPhone: '556',
      notes: 'updated note',
    );
    final updated = await db.getClient(clientId);
    expect(updated?.notes, 'updated note');
    expect(updated?.emergencyContactPhone, '556');

    final starts = DateTime(2026, 10, 28, 9, 30);
    await db.insertAppointment(clientId: clientId, startsAt: starts);

    final forClient = await db.watchAppointmentsForClient(clientId).first;
    expect(forClient, hasLength(1));
    expect(forClient.first.status, AppointmentStatus.scheduled);

    final today = await db.watchAppointmentsWithClientOnDay(starts).first;
    expect(today, hasLength(1));
    expect(today.first.client.lastName, 'Lovelace');
  });

  test('month appointment counts group by local day', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final clientId = await db.insertClient(
      firstName: 'Ada',
      lastName: 'Lovelace',
    );
    await db.insertAppointment(
      clientId: clientId,
      startsAt: DateTime(2026, 10, 28, 9),
    );
    await db.insertAppointment(
      clientId: clientId,
      startsAt: DateTime(2026, 10, 28, 14),
    );
    await db.insertAppointment(
      clientId: clientId,
      startsAt: DateTime(2026, 10, 29, 10),
    );
    await db.insertAppointment(
      clientId: clientId,
      startsAt: DateTime(2026, 11, 1, 10),
    );

    final counts =
        await db.watchAppointmentCountsForMonth(DateTime(2026, 10)).first;
    expect(counts[DateTime(2026, 10, 28)], 2);
    expect(counts[DateTime(2026, 10, 29)], 1);
    expect(counts.containsKey(DateTime(2026, 11, 1)), isFalse);
  });

  testWidgets('Calendar tab shows month grid and day list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final clientId = await db.insertClient(
      firstName: 'Ada',
      lastName: 'Lovelace',
    );
    final now = DateTime.now();
    await db.insertAppointment(
      clientId: clientId,
      startsAt: DateTime(now.year, now.month, now.day, 10),
    );

    await tester.pumpWidget(
      AppDatabaseProvider(
        database: db,
        syncEngine: const StubSyncEngine(),
        child: const MaterialApp(home: CalendarScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Tap a day to see appointments'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('Calendar empty-day well opens create for selected day',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      AppDatabaseProvider(
        database: db,
        syncEngine: const StubSyncEngine(),
        child: const MaterialApp(home: CalendarScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('No appointments this day.'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    // Tap the message (not the CTA) — whole well is the hit target.
    await tester.tap(find.text('No appointments this day.'));
    await tester.pumpAndSettle();

    expect(find.text('New appointment'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  test('SOAP stays editable; copy last is same-client only', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final clientId = await db.insertClient(
      firstName: 'Ada',
      lastName: 'Lovelace',
    );
    final otherId = await db.insertClient(
      firstName: 'Other',
      lastName: 'Client',
    );
    final appt1 = await db.insertAppointment(
      clientId: clientId,
      startsAt: DateTime(2026, 10, 1, 10),
    );
    final appt2 = await db.insertAppointment(
      clientId: clientId,
      startsAt: DateTime(2026, 10, 28, 10),
    );
    final otherAppt = await db.insertAppointment(
      clientId: otherId,
      startsAt: DateTime(2026, 10, 27, 10),
    );

    final first = await db.getOrCreateNoteForAppointment(
      appointmentId: appt1,
      clientId: clientId,
      noteDate: DateTime(2026, 10, 1, 10),
    );
    await db.updateNoteSoap(
      id: first.id,
      subjective: 'pain',
      objective: 'ROM limited',
      assessment: 'strain',
      plan: 'ice',
    );

    // Always editable after the fact.
    await db.updateNoteSoap(
      id: first.id,
      subjective: 'rewritten',
      objective: 'ROM limited',
      assessment: 'strain',
      plan: 'ice',
    );
    expect((await db.getNote(first.id))?.subjective, 'rewritten');

    final otherNote = await db.getOrCreateNoteForAppointment(
      appointmentId: otherAppt,
      clientId: otherId,
      noteDate: DateTime(2026, 10, 27, 10),
    );
    await db.updateNoteSoap(
      id: otherNote.id,
      subjective: 'other client',
      objective: 'x',
      assessment: 'x',
      plan: 'x',
    );

    final second = await db.getOrCreateNoteForAppointment(
      appointmentId: appt2,
      clientId: clientId,
      noteDate: DateTime(2026, 10, 28, 10),
    );
    final last = await db.getLastNoteForClient(
      clientId,
      exceptNoteId: second.id,
    );
    expect(last?.id, first.id);
    expect(last?.subjective, 'rewritten');

    expect(
      await db.copySoapIntoNote(targetId: second.id, source: last!),
      isTrue,
    );
    final copied = await db.getNote(second.id);
    expect(copied?.subjective, 'rewritten');
    expect(copied?.plan, 'ice');

    final again = await db.getOrCreateNoteForAppointment(
      appointmentId: appt2,
      clientId: clientId,
    );
    expect(again.id, second.id);

    final history = await db.watchNotesForClient(clientId).first;
    expect(history, hasLength(2));
  });

  test('client search matches name phone email; recent order + cap', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final ada = await db.insertClient(
      firstName: 'Ada',
      lastName: 'Lovelace',
      phone: '9123 4567',
      email: 'ada@example.com',
    );
    final grace = await db.insertClient(
      firstName: 'Grace',
      lastName: 'Hopper',
      phone: '555',
      email: 'grace@navy.mil',
    );
    final all = await db.watchClients().first;

    expect(filterClients(all, 'lovelace').single.id, ada);
    expect(filterClients(all, '9123').single.id, ada);
    expect(filterClients(all, 'navy.mil').single.id, grace);
    expect(filterClients(all, 'zzz'), isEmpty);

    await db.touchRecentClient(ada);
    await db.touchRecentClient(grace);
    await db.touchRecentClient(ada);
    expect(await db.watchRecentClientIds().first, [ada, grace]);

    for (var i = 0; i < AppDatabase.recentClientLimit + 2; i++) {
      final id = await db.insertClient(
        firstName: 'C$i',
        lastName: 'Client',
      );
      await db.touchRecentClient(id);
    }
    final recent = await db.watchRecentClientIds().first;
    expect(recent, hasLength(AppDatabase.recentClientLimit));
    expect(clientsInIdOrder(await db.watchClients().first, recent), hasLength(AppDatabase.recentClientLimit));
  });

  testWidgets('Clients tab search field and recent strip', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final ada = await db.insertClient(
      firstName: 'Ada',
      lastName: 'Lovelace',
      phone: '111',
    );
    await db.insertClient(firstName: 'Grace', lastName: 'Hopper');
    await db.touchRecentClient(ada);

    await tester.pumpWidget(
      AppDatabaseProvider(
        database: db,
        syncEngine: const StubSyncEngine(),
        child: const MaterialApp(home: ClientsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Search name, phone, or email'), findsOneWidget);
    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'hopper');
    await tester.pump();
    expect(find.text('RECENT'), findsNothing);
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
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
    expect(find.text('Go to client profile'), findsOneWidget);
    expect(find.byTooltip('Dictate'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
