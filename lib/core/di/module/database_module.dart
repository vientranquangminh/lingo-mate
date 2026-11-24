import 'package:injectable/injectable.dart';

import '../../database/app_database.dart';

/// Registers the local database.
@module
abstract class DatabaseModule {
  /// Opens the app database once for the whole app.
  @singleton
  AppDatabase get appDatabase => AppDatabase();
}
