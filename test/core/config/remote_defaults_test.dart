import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/config/remote_defaults.dart';

void main() {
  test('live flag default follows the flavor', () {
    expect(
      RemoteDefaults.values(liveEnabled: true)[RemoteDefaults.ffLiveEnabled],
      isTrue,
    );
    expect(
      RemoteDefaults.values(liveEnabled: false)[RemoteDefaults.ffLiveEnabled],
      isFalse,
    );
  });

  test('quota limits default is valid JSON with free and pro plans', () {
    final raw =
        RemoteDefaults.values(liveEnabled: false)[RemoteDefaults.quotaLimits]!
            as String;
    final limits = jsonDecode(raw) as Map<String, dynamic>;

    expect(limits.keys, containsAll(['free', 'pro']));
  });

  test('model names appear only in remote_defaults.dart', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('remote_defaults.dart'))
        .where(
          (f) => RegExp(r"'gemini-[\w.-]+'").hasMatch(f.readAsStringSync()),
        )
        .map((f) => f.path)
        .toList();

    expect(offenders, isEmpty);
  });
}
