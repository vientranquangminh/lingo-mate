import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/di/di.dart';

class AppConfiguration {
  AppConfiguration._();

  static Future<void> ensureAppConfiguration() async {
    await ScreenUtil.ensureScreenSize();
    await configureInjection();
    await getIt.allReady();
    registerFontLicenses();
  }

  static const mainAppSize = Size(375, 812);

  /// Adds the bundled fonts' OFL licence to the app's licence page.
  static void registerFontLicenses() {
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString(
        'assets/fonts/OFL-BeVietnamPro.txt',
      );
      yield LicenseEntryWithLineBreaks(['Be Vietnam Pro'], text);
    });
  }
}
