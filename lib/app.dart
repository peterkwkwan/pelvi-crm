import 'package:flutter/material.dart';

import 'data/database.dart';
import 'data/database_provider.dart';
import 'data/sync_stub.dart';
import 'features/first_run/first_run_screen.dart';
import 'features/shell/app_shell.dart';
import 'theme/theme.dart';

export 'data/database_provider.dart';

class PelviApp extends StatefulWidget {
  const PelviApp({
    super.key,
    required this.database,
    this.syncEngine = const StubSyncEngine(),
  });

  final AppDatabase database;
  final SyncEngine syncEngine;

  @override
  State<PelviApp> createState() => _PelviAppState();
}

class _PelviAppState extends State<PelviApp> {
  late Future<bool> _needsFirstRun;

  @override
  void initState() {
    super.initState();
    _needsFirstRun = _checkFirstRun();
  }

  Future<bool> _checkFirstRun() async {
    await widget.database.ensureDefaults();
    final name = await widget.database.getPractitionerName();
    return name == null || name.trim().isEmpty;
  }

  void _refreshGate() {
    setState(() {
      _needsFirstRun = Future.value(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppDatabaseProvider(
      database: widget.database,
      syncEngine: widget.syncEngine,
      child: MaterialApp(
        title: 'Pelvi',
        debugShowCheckedModeBanner: false,
        theme: pelviLightTheme(),
        home: FutureBuilder<bool>(
          future: _needsFirstRun,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: PelviColors.pink700),
                ),
              );
            }
            if (snapshot.data == true) {
              return FirstRunScreen(onComplete: _refreshGate);
            }
            return const AppShell();
          },
        ),
      ),
    );
  }
}
