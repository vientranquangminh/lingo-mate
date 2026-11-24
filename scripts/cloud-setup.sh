#!/bin/bash
set -euo pipefail

FLUTTER_VERSION=3.50.0
FVM_CACHE=/opt/fvm
PUB_CACHE_DIR=/opt/pub-cache
SDK="$FVM_CACHE/versions/$FLUTTER_VERSION"

git config --system --add safe.directory '*'

if [ ! -x "$SDK/bin/flutter" ]; then
  mkdir -p "$FVM_CACHE/versions"
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$SDK"
fi

ln -sf "$SDK/bin/flutter" /usr/local/bin/flutter
ln -sf "$SDK/bin/dart" /usr/local/bin/dart

export PUB_CACHE="$PUB_CACHE_DIR"
flutter config --no-analytics
flutter --version
flutter precache --no-android --no-ios || true
dart pub global activate fvm

cat > /usr/local/bin/fvm <<EOF
#!/bin/bash
export FVM_CACHE_PATH=$FVM_CACHE
export PUB_CACHE=$PUB_CACHE_DIR
exec $PUB_CACHE_DIR/bin/fvm "\$@"
EOF
chmod +x /usr/local/bin/fvm
chmod -R a+rwX "$FVM_CACHE" "$PUB_CACHE_DIR"
fvm --version

ANDROID_SDK=/opt/android-sdk
SDKMANAGER="$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKMANAGER" ]; then
  tmp=$(mktemp -d)
  curl -sSLo "$tmp/clt.zip" https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
  unzip -q "$tmp/clt.zip" -d "$tmp"
  mkdir -p "$ANDROID_SDK/cmdline-tools"
  mv "$tmp/cmdline-tools" "$ANDROID_SDK/cmdline-tools/latest"
  rm -rf "$tmp"
fi
yes | "$SDKMANAGER" --licenses > /dev/null || true
"$SDKMANAGER" "platform-tools" "platforms;android-36" "build-tools;36.0.0" > /dev/null
flutter config --android-sdk "$ANDROID_SDK"
chmod -R a+rwX "$ANDROID_SDK"
