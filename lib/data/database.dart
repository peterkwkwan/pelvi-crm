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
  int get schemaVersion => 1;

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
  }) {
    return into(clients).insert(
      ClientsCompanion.insert(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: Value(_blankToNull(phone)),
        email: Value(_blankToNull(email)),
        emergencyContact: Value(_blankToNull(emergencyContact)),
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
  }) async {
    final n = await (update(clients)..where((t) => t.id.equals(id))).write(
      ClientsCompanion(
        firstName: Value(firstName.trim()),
        lastName: Value(lastName.trim()),
        phone: Value(_blankToNull(phone)),
        email: Value(_blankToNull(email)),
        emergencyContact: Value(_blankToNull(emergencyContact)),
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

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
