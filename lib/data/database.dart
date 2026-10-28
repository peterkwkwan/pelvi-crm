import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'appointment_overlap.dart';
import 'recall.dart';

export 'recall.dart';

part 'database.g.dart';

/// Thrown when a create/update would overlap another appointment.
class AppointmentConflictException implements Exception {
  AppointmentConflictException(this.appointment, this.client);

  final Appointment appointment;
  final Client client;

  @override
  String toString() => 'AppointmentConflictException';
}

/// Appointment lifecycle statuses for MVP.
enum AppointmentStatus {
  scheduled,
  completed,
  cancelled,
  noShow,
}

/// Legacy note status; unused (notes stay editable).
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
  TextColumn get emergencyContactPhone => text().nullable()();
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
  /// Legacy column; unused (notes stay editable).
  TextColumn get addendum => text().withDefault(const Constant(''))();
  /// Legacy draft/final; unused (no lock).
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
  int get schemaVersion => 4;

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
          if (from < 4) {
            await m.addColumn(clients, clients.emergencyContactPhone);
          }
        },
      );

  static const practitionerNameKey = 'practitioner_name';
  static const recallDaysKey = 'recall_days';
  static const defaultRecallDays = '30';
  static const defaultAppointmentMinutesKey = 'default_appointment_minutes';
  static const defaultAppointmentMinutes = '60';
  /// Comma-separated client ids, most recently opened first.
  static const recentClientIdsKey = 'recent_client_ids';
  static const recentClientLimit = 8;

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

  Future<void> setRecallDays(int days) async {
    final clamped = days < 1 ? 1 : days;
    await setSetting(recallDaysKey, '$clamped');
  }

  Stream<int>? _recallDaysStream;

  Stream<int> watchRecallDays() {
    return _recallDaysStream ??= (select(settings)
          ..where((t) => t.key.equals(recallDaysKey)))
        .watch()
        .map((rows) {
          final raw = rows.isEmpty ? null : rows.first.value;
          return int.tryParse(raw ?? defaultRecallDays) ?? 30;
        })
        .asBroadcastStream();
  }

  Stream<List<RecallDueEntry>>? _recallDueStream;
  final _recallDueSubs = <StreamSubscription<Object?>>[];

  /// Clients with no non-cancelled appointment/note inside the recall window.
  ///
  /// Cached broadcast stream so StreamBuilders don't resubscribe every rebuild.
  Stream<List<RecallDueEntry>> watchRecallDueClients() {
    if (_recallDueStream != null) return _recallDueStream!;
    final controller = StreamController<List<RecallDueEntry>>.broadcast();
    var emitting = false;
    var queued = false;

    Future<void> emit() async {
      if (emitting) {
        queued = true;
        return;
      }
      emitting = true;
      do {
        queued = false;
        try {
          final due = await getRecallDueClients();
          if (!controller.isClosed) controller.add(due);
        } catch (e, st) {
          if (!controller.isClosed) controller.addError(e, st);
        }
      } while (queued);
      emitting = false;
    }

    void ping() => emit();
    _recallDueSubs.addAll([
      select(clients).watch().listen((_) => ping()),
      select(appointments).watch().listen((_) => ping()),
      select(notes).watch().listen((_) => ping()),
      (select(settings)..where((t) => t.key.equals(recallDaysKey)))
          .watch()
          .listen((_) => ping()),
    ]);
    _recallDueStream = controller.stream;
    return _recallDueStream!;
  }

  Future<List<RecallDueEntry>> getRecallDueClients({DateTime? now}) async {
    final clientsList = await (select(clients)
          ..orderBy([
            (t) => OrderingTerm.asc(t.lastName),
            (t) => OrderingTerm.asc(t.firstName),
          ]))
        .get();
    final appts = await select(appointments).get();
    final notesList = await select(notes).get();
    final days = await getRecallDays();
    return computeRecallDue(
      clients: clientsList,
      appointments: appts,
      notes: notesList,
      recallDays: days,
      now: now ?? DateTime.now(),
    );
  }

  @override
  Future<void> close() async {
    for (final s in _recallDueSubs) {
      await s.cancel();
    }
    _recallDueSubs.clear();
    _recallDueStream = null;
    _recallDaysStream = null;
    await super.close();
  }

  Future<int> getDefaultAppointmentMinutes() async {
    final raw = await getSetting(defaultAppointmentMinutesKey);
    return int.tryParse(raw ?? defaultAppointmentMinutes) ?? 60;
  }

  Future<void> ensureDefaults() async {
    final existing = await getSetting(recallDaysKey);
    if (existing == null) {
      await setSetting(recallDaysKey, defaultRecallDays);
    }
    final duration = await getSetting(defaultAppointmentMinutesKey);
    if (duration == null) {
      await setSetting(
        defaultAppointmentMinutesKey,
        defaultAppointmentMinutes,
      );
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

  static List<int> parseRecentClientIds(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return [
      for (final part in raw.split(','))
        if (int.tryParse(part.trim()) != null) int.parse(part.trim()),
    ];
  }

  Stream<List<int>> watchRecentClientIds() {
    return (select(settings)
          ..where((t) => t.key.equals(recentClientIdsKey)))
        .watch()
        .map(
          (rows) => parseRecentClientIds(
            rows.isEmpty ? null : rows.first.value,
          ),
        );
  }

  /// Record a profile open for the Clients recent strip.
  Future<void> touchRecentClient(int id) async {
    final current = List<int>.of(
      parseRecentClientIds(await getSetting(recentClientIdsKey)),
    );
    current.remove(id);
    current.insert(0, id);
    if (current.length > recentClientLimit) {
      current.removeRange(recentClientLimit, current.length);
    }
    await setSetting(recentClientIdsKey, current.join(','));
  }

  Future<int> insertClient({
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
    String? emergencyContact,
    String? emergencyContactPhone,
    String? notes,
  }) {
    return into(clients).insert(
      ClientsCompanion.insert(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: Value(_blankToNull(phone)),
        email: Value(_blankToNull(email)),
        emergencyContact: Value(_blankToNull(emergencyContact)),
        emergencyContactPhone: Value(_blankToNull(emergencyContactPhone)),
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
    String? emergencyContactPhone,
    String? notes,
  }) async {
    final n = await (update(clients)..where((t) => t.id.equals(id))).write(
      ClientsCompanion(
        firstName: Value(firstName.trim()),
        lastName: Value(lastName.trim()),
        phone: Value(_blankToNull(phone)),
        email: Value(_blankToNull(email)),
        emergencyContact: Value(_blankToNull(emergencyContact)),
        emergencyContactPhone: Value(_blankToNull(emergencyContactPhone)),
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

  /// Per-day appointment counts for [month] (any day in that calendar month).
  Stream<Map<DateTime, int>> watchAppointmentCountsForMonth(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return (select(appointments)
          ..where(
            (t) =>
                t.startsAt.isBiggerOrEqualValue(start) &
                t.startsAt.isSmallerThanValue(end),
          ))
        .watch()
        .map((rows) {
          final counts = <DateTime, int>{};
          for (final a in rows) {
            final d = DateTime(a.startsAt.year, a.startsAt.month, a.startsAt.day);
            counts[d] = (counts[d] ?? 0) + 1;
          }
          return counts;
        });
  }

  /// First overlapping appointment in the solo book, if any.
  ///
  /// shortcut: scans all rows, upgrade when diary is large
  Future<({Appointment appointment, Client client})?>
      findOverlappingAppointment({
    required DateTime startsAt,
    DateTime? endsAt,
    int? excludeId,
  }) async {
    final minutes = await getDefaultAppointmentMinutes();
    final newEnd = appointmentEffectiveEnd(startsAt, endsAt, minutes);
    final query = select(appointments).join([
      innerJoin(clients, clients.id.equalsExp(appointments.clientId)),
    ]);
    final rows = await query.get();
    for (final row in rows) {
      final other = row.readTable(appointments);
      if (excludeId != null && other.id == excludeId) continue;
      if (other.status == AppointmentStatus.cancelled) continue;
      final otherEnd =
          appointmentEffectiveEnd(other.startsAt, other.endsAt, minutes);
      if (appointmentsOverlap(
        startsAt,
        newEnd,
        other.startsAt,
        otherEnd,
      )) {
        return (
          appointment: other,
          client: row.readTable(clients),
        );
      }
    }
    return null;
  }

  Future<int> insertAppointment({
    required int clientId,
    required DateTime startsAt,
    DateTime? endsAt,
    AppointmentStatus status = AppointmentStatus.scheduled,
  }) async {
    final conflict = await findOverlappingAppointment(
      startsAt: startsAt,
      endsAt: endsAt,
    );
    if (conflict != null) {
      throw AppointmentConflictException(
        conflict.appointment,
        conflict.client,
      );
    }
    return into(appointments).insert(
      AppointmentsCompanion.insert(
        clientId: clientId,
        startsAt: startsAt,
        endsAt: Value(endsAt),
        status: Value(status),
      ),
    );
  }

  Future<bool> updateAppointment({
    required int id,
    required DateTime startsAt,
    DateTime? endsAt,
    AppointmentStatus? status,
  }) async {
    final existing = await getAppointment(id);
    if (existing == null) return false;
    final conflict = await findOverlappingAppointment(
      startsAt: startsAt,
      endsAt: endsAt ?? existing.endsAt,
      excludeId: id,
    );
    if (conflict != null) {
      throw AppointmentConflictException(
        conflict.appointment,
        conflict.client,
      );
    }
    final n = await (update(appointments)..where((t) => t.id.equals(id))).write(
      AppointmentsCompanion(
        startsAt: Value(startsAt),
        endsAt: endsAt == null ? const Value.absent() : Value(endsAt),
        status: status == null ? const Value.absent() : Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return n > 0;
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

  Future<void> updateNoteSoap({
    required int id,
    required String subjective,
    required String objective,
    required String assessment,
    required String plan,
  }) async {
    final note = await getNote(id);
    if (note == null) return;
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

  /// Copy S/O/A/P from [source] into [targetId] (same-client caller checks).
  Future<bool> copySoapIntoNote({
    required int targetId,
    required Note source,
  }) async {
    final target = await getNote(targetId);
    if (target == null) return false;
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
