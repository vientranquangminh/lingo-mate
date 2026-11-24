#!/bin/bash
# Generates Firebase configuration files for each flavor (dev, staging, prod).
# Android only for now. Only dev is connected (Firebase project lingo-mate-4f38d);
# the staging and prod projects do not exist yet: set their ids here once created.
# Requires the FlutterFire CLI: dart pub global activate flutterfire_cli
#
# Each run writes lib/firebase_options_<flavor>.dart, which the app loads for
# that flavor, plus the flavor's google-services.json.

if [[ $# -eq 0 ]]; then
  echo "Error: No environment specified. Use 'dev', 'staging', or 'prod'."
  exit 1
fi

case $1 in
  dev)
    flutterfire config \
      --platforms=android \
      --project=lingo-mate-4f38d \
      --out=lib/firebase_options_dev.dart \
      --android-package-name=com.lingomate.app.dev \
      --android-out=android/app/src/dev/google-services.json
    ;;
  staging)
    flutterfire config \
      --platforms=android \
      --project=lingomate-staging \
      --out=lib/firebase_options_staging.dart \
      --android-package-name=com.lingomate.app.staging \
      --android-out=android/app/src/staging/google-services.json
    ;;
  prod)
    flutterfire config \
      --platforms=android \
      --project=lingomate-prod \
      --out=lib/firebase_options_prod.dart \
      --android-package-name=com.lingomate.app \
      --android-out=android/app/src/production/google-services.json
    ;;
  *)
    echo "Error: Invalid environment specified. Use 'dev', 'staging', or 'prod'."
    exit 1
    ;;
esac
