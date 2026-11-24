import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/resources/app_config.dart';
import 'common/utils/riverpod_logger.dart';
import 'firebase_options_dev.dart';
import 'flavor_config.dart';
import 'my_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlavorConfig(appFlavor: Flavor.development);
  AppConfiguration.ensureAppConfiguration();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then(
    (value) => runApp(
      ProviderScope(observers: [RiverpodLogger()], child: const MyApp()),
    ),
  );
}
