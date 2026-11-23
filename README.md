# Flutter Template

## Usage

Clone the repository

`git clone git@github.com:vientranquangminh/lingo-mate.git`

## Prerequisite

- Flutter 3.50.0 (pinned in `.fvmrc`)
- Flutter version manager (recommend): [fvm](https://fvm.app/)

## Migrating from the old template

Projects created from the old template (Flutter 3.47, `flutter_platform_widgets`) can follow [docs/migrating-from-old-template.md](docs/migrating-from-old-template.md).

## Getting Started

### Setup

- Create these `.env` files in the root directory according to the flavors and add the required
  environment variables into them. The example environment variable is in `.env.sample`.

    - Dev: `.env.dev`

    - Staging: `.env.staging`

    - Production: `.env`

- Get packages (this also generates the localizations from `lib/l10n/*.arb` into `lib/generated/`; run `$ fvm flutter gen-l10n` after editing an ARB file):

    - `$ fvm flutter pub get`

- Run code generator:

    - `$ fvm dart run build_runner build --delete-conflicting-outputs`

### Run

- Run the app with the desire app flavor:

    - Dev: `$ fvm flutter run --flavor dev --target lib/main_dev.dart --dart-define-from-file=.env.dev`

    - Staging: `$ fvm flutter run --flavor staging --target lib/main_staging.dart --dart-define-from-file=.env.staging`

    - Production: `$ fvm flutter run --flavor production --target lib/main.dart --dart-define-from-file=.env`

## Firebase

- Install the FlutterFire CLI: `$ dart pub global activate flutterfire_cli`
- Set the Firebase project ids and bundle ids in `flutterfire-config.sh` (or `flutterfire-config.ps1` on Windows), then run it once per flavor:

    - `$ ./flutterfire-config.sh dev|staging|prod`

## CI (Azure Pipelines)

`azure-pipelines.yml` (with `ci/templates/flutter-setup.yml`) installs the Flutter version from `.fvmrc`, then:

- On pull requests to `main`: runs `flutter analyze` and `flutter test` and publishes the test results.
- On pushes to `main`: waits for approval on the `production` environment, builds the signed production app bundle, uploads it to the Google Play internal track and, when `firebaseAndroidAppId` is set, uploads the Dart symbols to Crashlytics.

It needs these in Azure DevOps: the secure files `signing.properties`, `key-release.jks` and `env.production` (plus `firebase-crashlytics-sa.json` for Crashlytics), the `production` environment and the `Google Play service connection` service connection. Set `applicationId` in the Google Play step to your production app id.

## License

This project is Copyright (c) 2014 and onwards. It is free software,
and may be redistributed under the terms specified in the [LICENSE] file.

[LICENSE]: /LICENSE