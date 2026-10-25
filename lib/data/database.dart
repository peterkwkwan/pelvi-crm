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
}
