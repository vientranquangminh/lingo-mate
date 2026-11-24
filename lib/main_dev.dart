import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/resources/app_config.dart';
import 'common/utils/riverpod_logger.dart';
import 'core/config/remote_config_service.dart';
import 'core/di/di.dart';
import 'core/errors/crash_reporter.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'firebase_options_dev.dart';
import 'flavor_config.dart';
import 'my_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig(appFlavor: Flavor.development);
  await bootstrapFirebase(DefaultFirebaseOptions.currentPlatform);
  await AppConfiguration.ensureAppConfiguration();
  await getIt<CrashReporter>().installErrorHandlers();
  await getIt<RemoteConfigService>().initialize();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then(
    (value) => runApp(
      ProviderScope(observers: [RiverpodLogger()], child: const MyApp()),
    ),
  );
}
