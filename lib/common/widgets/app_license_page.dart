import 'package:material_ui/material_ui.dart';

/// Opens the open-source license list with [legalese] under the app name (AC-10.5).
void showAppLicensePage(
  BuildContext context, {
  required String appName,
  required String legalese,
}) => showLicensePage(
  context: context,
  applicationName: appName,
  applicationLegalese: legalese,
  useRootNavigator: true,
);
