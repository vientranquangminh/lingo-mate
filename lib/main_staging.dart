import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/resources/app_config.dart';
import 'core/licenses/app_licenses.dart';
import 'common/utils/riverpod_logger.dart';
import 'flavor_config.dart';
import 'my_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig(appFlavor: Flavor.staging);
  AppConfiguration.ensureAppConfiguration();
  registerAppLicenses();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then(
    (value) => runApp(
      ProviderScope(observers: [RiverpodLogger()], child: const MyApp()),
    ),
  );
}
