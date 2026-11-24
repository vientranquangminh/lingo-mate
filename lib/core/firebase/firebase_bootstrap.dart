import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../env.dart';
import '../../flavor_config.dart';

/// Initialises Firebase and App Check for the current flavor.
Future<void> bootstrapFirebase(FirebaseOptions options) async {
  await Firebase.initializeApp(options: options);
  final isDev = FlavorConfig.instance.appFlavor == Flavor.development;
  final debugToken = Env.appCheckDebugToken;
  await FirebaseAppCheck.instance.activate(
    providerAndroid: isDev
        ? AndroidDebugProvider(
            debugToken: debugToken.isEmpty ? null : debugToken,
          )
        : const AndroidPlayIntegrityProvider(),
  );
}
