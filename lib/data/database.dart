import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Appointment lifecycle statuses for MVP.
enum AppointmentStatus {
  scheduled,
  completed,
  cancelled,
  noShow,
}

/// Note draft vs finalized.
enum NoteStatus {
  draft,
  finalized,
}

class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get firstName => text().withLength(min: 1, max: 120)();
  TextColumn get lastName => text().withLength(min: 1, max: 120)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  DateTimeColumn get joinDate => dateTime().nullable()();
  DateTimeColumn get birthday => dateTime().nullable()();
  TextColumn get emergencyContact => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Appointments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id)();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  IntColumn get status => intEnum<AppointmentStatus>()
      .withDefault(Constant(AppointmentStatus.scheduled.index))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId => integer().references(Clients, #id)();
  IntColumn get appointmentId =>
      integer().nullable().references(Appointments, #id)();
  DateTimeColumn get noteDate => dateTime()();
  TextColumn get subjective => text().withDefault(const Constant(''))();
  TextColumn get objective => text().withDefault(const Constant(''))();
  TextColumn get assessment => text().withDefault(const Constant(''))();
  TextColumn get plan => text().withDefault(const Constant(''))();
  /// Append-only after finalize; S/O/A/P stay locked.
  TextColumn get addendum => text().withDefault(const Constant(''))();
  IntColumn get status =>
      intEnum<NoteStatus>().withDefault(Constant(NoteStatus.draft.index))();
  DateTimeColumn get finalizedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Key/value settings (practitioner name, recall days, …).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [Clients, Appointments, Notes, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(notes, notes.addendum);
          }
          if (from < 3) {
            await m.addColumn(clients, clients.notes);
          }
        },
      );

  static const practitionerNameKey = 'practitioner_name';
  static const recallDaysKey = 'recall_days';
  static const defaultRecallDays = '30';

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'pelvi_crm');
  }

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<String?> getPractitionerName() => getSetting(practitionerNameKey);

  Future<void> setPractitionerName(String name) =>
      setSetting(practitionerNameKey, name.trim());

  Future<int> getRecallDays() async {
    final raw = await getSetting(recallDaysKey);
    return int.tryParse(raw ?? defaultRecallDays) ?? 30;
  }

  Future<void> ensureDefaults() async {
    final existing = await getSetting(recallDaysKey);
    if (existing == null) {
      await setSetting(recallDaysKey, defaultRecallDays);
    }
  }

  Stream<List<Client>> watchClients() {
    return (select(clients)
          ..orderBy([
            (t) => OrderingTerm.asc(t.lastName),
            (t) => OrderingTerm.asc(t.firstName),
          ]))
        .watch();
  }

  Future<Client?> getClient(int id) {
    return (select(clients)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Client?> watchClient(int id) {
    return (select(clients)..where((t) => t.id.equals(id)))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<int> insertClient({
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
    String? emergencyContact,
    String? notes,
  }) {
    return into(clients).insert(
      ClientsCompanion.insert(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: Value(_blankToNull(phone)),
        email: Value(_blankToNull(email)),
        emergencyContact: Value(_blankToNull(emergencyContact)),
        notes: Value(_blankToNull(notes)),
      ),
    );
  }

  Future<bool> updateClient({
    required int id,
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
    String? emergencyContact,
    String? notes,
  }) async {
    final n = await (update(clients)..where((t) => t.id.equals(id))).write(
      ClientsCompanion(
        firstName: Value(firstName.trim()),
        lastName: Value(lastName.trim()),
        phone: Value(_blankToNull(phone)),
        email: Value(_blankToNull(email)),
        emergencyContact: Value(_blankToNull(emergencyContact)),
        notes: Value(_blankToNull(notes)),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return n > 0;
  }

  Stream<List<Appointment>> watchAppointmentsForClient(int clientId) {
    return (select(appointments)
          ..where((t) => t.clientId.equals(clientId))
          ..orderBy([(t) => OrderingTerm.desc(t.startsAt)]))
        .watch();
  }

  /// Appointments whose [Appointments.startsAt] falls on [day] (local date).
  Stream<List<({Appointment appointment, Client client})>>
      watchAppointmentsWithClientOnDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final query = select(appointments).join([
      innerJoin(clients, clients.id.equalsExp(appointments.clientId)),
    ])
      ..where(
        appointments.startsAt.isBiggerOrEqualValue(start) &
            appointments.startsAt.isSmallerThanValue(end),
      )
      ..orderBy([OrderingTerm.asc(appointments.startsAt)]);
    return query.watch().map(
          (rows) => [
            for (final row in rows)
              (
                appointment: row.readTable(appointments),
                client: row.readTable(clients),
              ),
          ],
        );
  }

  Future<int> insertAppointment({
    required int clientId,
    required DateTime startsAt,
    DateTime? endsAt,
    AppointmentStatus status = AppointmentStatus.scheduled,
  }) {
    return into(appointments).insert(
      AppointmentsCompanion.insert(
        clientId: clientId,
        startsAt: startsAt,
        endsAt: Value(endsAt),
        status: Value(status),
      ),
    );
  }

  Future<Appointment?> getAppointment(int id) {
    return (select(appointments)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<Note?> watchNote(int id) {
    return (select(notes)..where((t) => t.id.equals(id)))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<Note?> getNote(int id) {
    return (select(notes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Note?> getNoteForAppointment(int appointmentId) {
    return (select(notes)..where((t) => t.appointmentId.equals(appointmentId)))
        .getSingleOrNull();
  }

  /// Visit history: notes for a client, newest first.
  Stream<List<Note>> watchNotesForClient(int clientId) {
    return (select(notes)
          ..where((t) => t.clientId.equals(clientId))
          ..orderBy([(t) => OrderingTerm.desc(t.noteDate)]))
        .watch();
  }

  /// Most recent note for [clientId], excluding [exceptNoteId] when set.
  Future<Note?> getLastNoteForClient(int clientId, {int? exceptNoteId}) async {
    final query = select(notes)
      ..where((t) => t.clientId.equals(clientId))
      ..orderBy([(t) => OrderingTerm.desc(t.noteDate)])
      ..limit(5);
    final rows = await query.get();
    for (final n in rows) {
      if (exceptNoteId != null && n.id == exceptNoteId) continue;
      return n;
    }
    return null;
  }

  /// Open existing note for the appointment, or create a draft.
  Future<Note> getOrCreateNoteForAppointment({
    required int appointmentId,
    required int clientId,
    DateTime? noteDate,
  }) async {
    final existing = await getNoteForAppointment(appointmentId);
    if (existing != null) return existing;
    final id = await into(notes).insert(
      NotesCompanion.insert(
        clientId: clientId,
        appointmentId: Value(appointmentId),
        noteDate: noteDate ?? DateTime.now(),
      ),
    );
    return (await getNote(id))!;
  }

  Future<void> updateNoteDraft({
    required int id,
    required String subjective,
    required String objective,
    required String assessment,
    required String plan,
  }) async {
    final note = await getNote(id);
    if (note == null || note.status != NoteStatus.draft) return;
    await (update(notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        subjective: Value(subjective),
        objective: Value(objective),
        assessment: Value(assessment),
        plan: Value(plan),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<bool> finalizeNote(int id) async {
    final note = await getNote(id);
    if (note == null || note.status != NoteStatus.draft) return false;
    final n = await (update(notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        status: const Value(NoteStatus.finalized),
        finalizedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return n > 0;
  }

  Future<void> updateNoteAddendum({
    required int id,
    required String addendum,
  }) async {
    final note = await getNote(id);
    if (note == null || note.status != NoteStatus.finalized) return;
    await (update(notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        addendum: Value(addendum),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Copy S/O/A/P from [source] into a draft [targetId]. No-op if not draft.
  Future<bool> copySoapIntoDraft({
    required int targetId,
    required Note source,
  }) async {
    final target = await getNote(targetId);
    if (target == null || target.status != NoteStatus.draft) return false;
    await (update(notes)..where((t) => t.id.equals(targetId))).write(
      NotesCompanion(
        subjective: Value(source.subjective),
        objective: Value(source.objective),
        assessment: Value(source.assessment),
        plan: Value(source.plan),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return true;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
