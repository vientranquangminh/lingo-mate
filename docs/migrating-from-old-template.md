# Migrating a project from the old template

This guide moves a project that was created from the old template (Flutter 3.47 or
earlier, `flutter_platform_widgets`, intl_utils, the Petbarn palette and fonts) to the current one:
Flutter 3.50.0, `material_ui` / `cupertino_ui`, gen-l10n, the shared `AppPlatform*` widgets, Azure
Pipelines and the FlutterFire scripts.

Work on a branch and run `fvm dart run build_runner build --delete-conflicting-outputs`,
`fvm flutter analyze` and `fvm flutter test` after each step that touches Dart code.

## 1. Flutter 3.50.0

1. Set the version in `.fvmrc` and install it:

   ```json
   {
     "flutter": "3.50.0"
   }
   ```

   ```sh
   fvm install
   ```

2. Point VS Code at it in `.vscode/settings.json`:
   `"dart.flutterSdkPath": ".fvm/versions/3.50.0"`.
3. Raise the Dart constraint in `pubspec.yaml`: `sdk: ">=3.14.0 <4.0.0"`.
4. Update the Flutter version in `README.md`.

## 2. Dependencies

1. In `pubspec.yaml`:
   - remove `flutter_platform_widgets`;
   - remove `dartx` if nothing imports it (`grep -rn "package:dartx" lib`);
   - add the decoupled design libraries:

     ```yaml
     material_ui: ^1.11.0
     cupertino_ui: ^1.1.6
     ```

2. Upgrade the rest:

   ```sh
   fvm flutter pub upgrade --major-versions
   ```

   This moves `equatable` to 3.x and `cupertino_icons` to 2.x. Read the changelog of
   every package that changed its major version and fix anything they break.

## 3. Move to material_ui and cupertino_ui

Material and Cupertino no longer live in the framework.

1. Migrate the imports with the data-driven fix:

   ```sh
   fvm dart fix --apply --code=migrate_design_widgets
   ```

2. Replace anything the fix left behind:

   | Old import | New import |
   |---|---|
   | `package:flutter/material.dart` | `package:material_ui/material_ui.dart` |
   | `package:flutter/cupertino.dart` | `package:cupertino_ui/cupertino_ui.dart` |

   `package:flutter/foundation.dart`, `services.dart` and `widgets.dart` stay as they are.

3. Localizations: replace the list of `Global*Localizations.delegate` entries with the
   delegates from `material_ui`:

   ```dart
   static const _localizationsDelegates = [
     AppLocalizations.delegate,
     ...GlobalMaterialLocalizations.delegates,
   ];
   ```

4. If a third-party package still builds widgets from `package:flutter/material.dart` and
   renders wrongly, wrap it (or the whole app in `MaterialApp.builder`) in
   `MaterialUiCompatibilityBridge`.

## 4. Drop flutter_platform_widgets

1. Copy these files from the template into `lib/common`:
   - `extensions/platform_ext.dart` (`context.isCupertino`)
   - `resources/app_params.dart`
   - `widgets/app_circular_progress_indicator.dart`, `app_scaffold.dart`,
     `app_platform_app_bar.dart`, `app_platform_nav_bar.dart`,
     `app_platform_elevated_button.dart`, `app_platform_outlined_button.dart`,
     `app_platform_text_button.dart`, `app_platform_icon_button.dart`,
     `loading_overlay.dart`, `keep_alive_wrapper.dart`

2. Rewrite `lib/my_app.dart` so it builds `CupertinoApp.router` on iOS and macOS and
   `MaterialApp.router` everywhere else, with one shared builder. Copy it from the
   template. Its shape is:

   ```dart
   child: _isCupertinoPlatform
       ? CupertinoApp.router(
           localizationsDelegates: _localizationsDelegates,
           supportedLocales: AppLocalizations.delegate.supportedLocales,
           builder: (context, child) => _buildRoot(context, child, cupertino: true),
           routerConfig: router,
         )
       : MaterialApp.router(
           localizationsDelegates: _localizationsDelegates,
           supportedLocales: AppLocalizations.delegate.supportedLocales,
           builder: (context, child) => _buildRoot(context, child, cupertino: false),
           routerConfig: router,
         ),
   ```

   `_buildRoot` calls `ScreenUtil.init`, then wraps the page in `Portal`, `Theme` and, on
   Cupertino, `CupertinoTheme`.

3. Replace the remaining `flutter_platform_widgets` APIs:

   | Old | New |
   |---|---|
   | `PlatformApp.router` + `MaterialAppRouterData` / `CupertinoAppRouterData` | `MaterialApp.router` / `CupertinoApp.router` (step 2) |
   | `platformThemeData(context, material: …, cupertino: …)` | the `_style` helper in `text_style_ext.dart` |
   | `isMaterial(context)` / `isCupertino(context)` | `context.isCupertino` |
   | `PlatformCircularProgressIndicator` | `AppCircularProgressIndicator` |
   | `PlatformScaffold` | `AppPlatformScaffold` |
   | `PlatformAppBar` | `AppPlatformAppBar` |
   | `PlatformElevatedButton` | `AppPlatformElevatedButton` |
   | `PlatformTextButton` | `AppPlatformTextButton` |
   | `PlatformIconButton` | `AppPlatformIconButton` |
   | `PlatformNavBar` | `AppPlatformNavBar` |
   | `PlatformWidget(material: …, cupertino: …)` | `context.isCupertino ? … : …`, or a new `AppPlatform*` widget in `lib/common/widgets` |

   When there is no shared widget for something yet, add one to `lib/common/widgets` that
   builds the Material or the Cupertino widget from `context.isCupertino`.

4. Check that nothing is left:

   ```sh
   grep -rn "flutter_platform_widgets\|package:flutter/material.dart\|package:flutter/cupertino.dart" lib test
   ```

## 5. Sizes and text styles

`Dimens` used to hold sizes that were already scaled (`static final fontSize14 = 14.sp`).
It now holds **unscaled** constants from the Material 3 type scale only (11, 12, 14, 16,
22, 24, 28, 32, 36, 45, 57), and you scale them where they are used.

1. Replace `lib/common/resources/dimens.dart` with the template's.
2. Add `.sp` at every use: `fontSize: Dimens.fontSize14` → `fontSize: Dimens.fontSize14.sp`.
3. Sizes that are not on the scale (8, 10, 17, 18, 20, 26, 30, 40, …) no longer exist.
   Round each one to the nearest size on the scale.
4. `Dimens.radius16` and `Dimens.space8` move to `AppParams` (scale them with `.r` / `.w` /
   `.h` where used).
5. Rewrite each getter in `text_style_ext.dart` with `_style`, named
   `<weight>Size<N><Colour>Text`, for example:

   ```dart
   TextStyle? get regularSize14BlackText => _style(
     material: (data) => data.textTheme.bodyMedium?.copyWith(
       color: ColorName.black,
       fontSize: Dimens.fontSize14.sp,
       fontWeight: FontWeight.w400,
     ),
     cupertino: (data) => data.textTheme.textStyle.copyWith(
       color: ColorName.black,
       fontSize: Dimens.fontSize14.sp,
       fontWeight: FontWeight.w400,
     ),
   );
   ```

## 6. Localizations: intl_utils to gen-l10n

The old template generated `AppLocalizations` with intl_utils (the `flutter_intl` block).
The template now uses Flutter's built-in gen-l10n, the same as mojimo.

1. In `pubspec.yaml`, remove `intl_utils` from `dev_dependencies` and the `flutter_intl:`
   block. Keep `intl`, `flutter_localizations` and `flutter: generate: true`.
2. Add `l10n.yaml` at the project root:

   ```yaml
   arb-dir: lib/l10n
   template-arb-file: intl_en.arb
   output-dir: lib/generated
   output-localization-file: l10n.dart
   output-class: AppLocalizations
   nullable-getter: false
   ```

   The output keeps the old path and class name, so `import '…/generated/l10n.dart'` and
   `AppLocalizations.of(context)` keep working.
3. Delete the committed intl_utils output and ignore the folder:

   ```sh
   git rm -r lib/generated
   echo "/lib/generated/" >> .gitignore
   fvm flutter pub get
   ```

   `flutter pub get` (and `flutter gen-l10n`) writes `lib/generated/l10n.dart` and one
   `l10n_<locale>.dart` per ARB file.
4. Replace `AppLocalizations.delegate.supportedLocales` with
   `AppLocalizations.supportedLocales`.
5. Fix the API differences:

   | intl_utils | gen-l10n |
   |---|---|
   | `AppLocalizations.current.key` (no context) | not available: pass a `BuildContext` and use `AppLocalizations.of(context).key`, or look the strings up with `lookupAppLocalizations(locale)` |
   | `AppLocalizations.load(locale)` | not needed; the delegate loads the locale |
   | `intl_<locale>.arb` with `@@locale` | unchanged |
   | placeholders without metadata | each placeholder needs an `@key` entry with `placeholders` when it isn't a plain `String`, e.g. an `int` used in a plural |

   Then find anything left over:

   ```sh
   grep -rn "AppLocalizations.current\|AppLocalizations.load\|delegate.supportedLocales\|intl_utils" lib test
   ```

## 7. Remove the Petbarn leftovers

The old template shipped with branding from Petbarn. Replace or remove each item, unless
the project really is a Petbarn app:

| Where | Old value | Fix |
|---|---|---|
| `android/app/src/{dev,staging,production}/res/values/strings.xml` | `Pet Barn`, `Pet Barn Dev`, `Pet Barn Staging` | your app name |
| `android/app/src/main/AndroidManifest.xml` | `android:label="flutter_template"` | `android:label="@string/app_name"` |
| `ios/Runner/Info.plist` | `CFBundleDisplayName` `Petbarn Flutter`, `CFBundleName` `petbarn_flutter` | your app name |
| `assets/fonts/Neutraface_Text_*.otf` and the `fonts:` block in `pubspec.yaml` | Petbarn's brand font, a paid font | delete them unless you hold a licence; drop `fontFamily: FontFamily.neutrafaceText` from the theme |
| `assets/color/colors.xml` | Petbarn's purple palette | your palette (step 8) |
| `lib/common/resources/app_theme.dart` | `purpleRhythm` / `purpleCyberGrape` colours, white text | a `ColorScheme.fromSeed` theme, as in the template |
| `README.md` | `techsoft-code/flutter-template` clone URL | your repository |
| `lib/core/api/api_service.dart` | `/api/website/v1/auth/signin` | your own API |

Search for anything else:

```sh
grep -rniI "petbarn\|pet barn\|neutraface\|techsoft" --exclude-dir=.git --exclude-dir=.dart_tool .
```

## 8. Colours

1. Move `assets/color/colors.xml` to `assets/color/values/colors.xml` and update
   `flutter_gen.colors.inputs` in `pubspec.yaml`.
2. Let Android read the same file as a resource in `android/app/build.gradle`:

   ```groovy
   sourceSets {
       main.java.srcDirs += 'src/main/kotlin'
       main.res.srcDirs += '../../assets/color'
   }
   ```

3. Remove duplicate names. The old file defined `gray`, `gray_platinum`, `pink_paradise`,
   `purple_jacarta` and others twice, which breaks the Android resource merge. Names with
   hyphens or capitals (`purple-space-cadet`, `black_chinese_Black`) are invalid too.
4. Name colours the way `CLAUDE.md` says (`<main colour>_<name>` from meodai/color-names)
   and replace every `Colors.white`, `Colors.black54`, `Color(0x…)` and
   `@android:color/…` with an entry from the file (`Colors.transparent` is fine).
   For example, `launch_background.xml` uses `@color/white`.

## 9. Analyzer fixes from Dart 3.14

`prefer_initializing_formals` now flags constructors that copy a named parameter into a
private field. Use a private initializing formal instead. Generated injectable code keeps
the public name (`storage:`), so callers don't change:

```dart
StorageRepositoryImpl({required this._storage, required this._pref}) {
  _validateFirstInstall();
}
```

## 10. CI and Firebase

1. Copy `azure-pipelines.yml` and `ci/templates/flutter-setup.yml`. Then:
   - set `applicationId` in the Google Play step to your production app id;
   - set `firebaseAndroidAppId` if the app uses Crashlytics (the job is skipped while it
     is empty);
   - in Azure DevOps, add the secure files `signing.properties`, `key-release.jks`,
     `env.production` (and `firebase-crashlytics-sa.json` for Crashlytics), the
     `production` environment and the `Google Play service connection`;
   - add your own env-key checks before the build step if the app has required keys.
2. Copy `flutterfire-config.sh` and `flutterfire-config.ps1`, set your Firebase project ids
   and bundle ids, then run `./flutterfire-config.sh dev|staging|prod`.
3. The PR stage runs `flutter test`, which fails when there are no tests. Replace an empty
   `test/widget_test.dart` with at least one real test (the template has
   `test/result_test.dart`).
4. Remove the stray `"--dart-define", ".env.staging"` / `".env"` arguments from the staging
   and production entries in `.vscode/launch.json`.

## 11. Project rules

Copy `CLAUDE.md` and update `.agents/CONTEXT.md` (the UI and Styling bullets and the
`common/` folders). Adjust the rules to your project.

## 12. Check

```sh
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format lib test
fvm flutter analyze
fvm flutter test
fvm flutter build appbundle --flavor dev --target lib/main_dev.dart --dart-define-from-file=.env.dev
fvm flutter build ios --flavor dev --target lib/main_dev.dart --dart-define-from-file=.env.dev --no-codesign
```

Then run the app on an Android device and an iOS device. Check the Material and the
Cupertino look, the app name on the home screen, the fonts and the colours.
