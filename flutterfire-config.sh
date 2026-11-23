#!/bin/bash
# Generates Firebase configuration files for each flavor (dev, staging, prod).
# Set --project and the bundle ids below to your Firebase projects and app ids.
# Requires the FlutterFire CLI: dart pub global activate flutterfire_cli
#
# Each run writes lib/firebase_options_<flavor>.dart, which the app loads for
# that flavor, plus the flavor's google-services.json and GoogleService-Info.plist.
# On macOS the plist is bundled into the flavor's Release build configuration.

if [[ $# -eq 0 ]]; then
  echo "Error: No environment specified. Use 'dev', 'staging', or 'prod'."
  exit 1
fi

case $1 in
  dev)
    flutterfire config \
      --platforms=android,ios \
      --project=template-dev \
      --out=lib/firebase_options_dev.dart \
      --ios-bundle-id=com.example.template.dev \
      --ios-out=ios/flavors/dev/GoogleService-Info.plist \
      --ios-build-config=Release-dev \
      --android-package-name=com.example.template.dev \
      --android-out=android/app/src/dev/google-services.json
    ;;
  staging)
    flutterfire config \
      --platforms=android,ios \
      --project=template-staging \
      --out=lib/firebase_options_staging.dart \
      --ios-bundle-id=com.example.template.staging \
      --ios-out=ios/flavors/staging/GoogleService-Info.plist \
      --ios-build-config=Release-staging \
      --android-package-name=com.example.template.staging \
      --android-out=android/app/src/staging/google-services.json
    ;;
  prod)
    flutterfire config \
      --platforms=android,ios \
      --project=template-prod \
      --out=lib/firebase_options_production.dart \
      --ios-bundle-id=com.example.template.prod \
      --ios-out=ios/flavors/production/GoogleService-Info.plist \
      --ios-build-config=Release-production \
      --android-package-name=com.example.template.prod \
      --android-out=android/app/src/production/google-services.json
    ;;
  *)
    echo "Error: Invalid environment specified. Use 'dev', 'staging', or 'prod'."
    exit 1
    ;;
esac
