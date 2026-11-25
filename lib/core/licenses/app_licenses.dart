import 'package:flutter/foundation.dart';

/// Adds the attributions of native SDKs that Flutter's license list misses (AC-10.5).
void registerAppLicenses() {
  LicenseRegistry.addLicense(
    () => Stream.fromIterable(const [
      LicenseEntryWithLineBreaks(
        ['Google ML Kit'],
        'ML Kit on-device translation and language identification are '
        'provided by Google under the ML Kit Terms of Service '
        '(https://developers.google.com/ml-kit/terms). Translation models are '
        'downloaded from Google on demand.',
      ),
      LicenseEntryWithLineBreaks(
        ['sherpa-onnx'],
        'sherpa-onnx, Copyright (c) Xiaomi Corporation and contributors. '
        'Licensed under the Apache License, Version 2.0.',
      ),
      LicenseEntryWithLineBreaks(
        ['whisper.cpp', 'OpenAI Whisper models'],
        'whisper.cpp, Copyright (c) Georgi Gerganov. Licensed under the MIT '
        'License. Whisper model weights, Copyright (c) OpenAI. Licensed under '
        'the MIT License.',
      ),
      LicenseEntryWithLineBreaks(
        ['Silero VAD'],
        'Silero VAD, Copyright (c) Silero Team. Licensed under the MIT License.',
      ),
    ]),
  );
}
