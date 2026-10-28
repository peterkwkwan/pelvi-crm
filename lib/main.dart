import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/local_notifications.dart';
import 'theme/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: PelviColors.canvas,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final database = AppDatabase();
  await database.ensureDefaults();
  await LocalNotifications.init();

  runApp(PelviApp(database: database));
}
