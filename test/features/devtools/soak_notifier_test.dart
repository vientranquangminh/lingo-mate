import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/audio/audio_capture.dart';
import 'package:lingo_mate/core/background/background_capture.dart';
import 'package:lingo_mate/features/devtools/data/notifier/devtools_providers.dart';
import 'package:lingo_mate/features/devtools/data/notifier/soak_notifier.dart';

import '../../core/audio/audio_test_utils.dart';

/// Records service and overlay calls; the test pushes notification and overlay events.
class _FakeBackground implements BackgroundCapture {
  _FakeBackground({this.overlayAllowed = true});

  final bool overlayAllowed;
  final controller = StreamController<BackgroundEvent>.broadcast();
  bool serviceRunning = false;
  bool overlayVisible = false;
  List<String> overlayLines = const [];

  @override
  Stream<BackgroundEvent> get events => controller.stream;

  @override
  Future<void> startService() async => serviceRunning = true;

  @override
  Future<void> stopService() async => serviceRunning = false;

  @override
  Future<bool> canDrawOverlays() async => overlayAllowed;

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<bool> showOverlay() async => overlayVisible = overlayAllowed;

  @override
  Future<void> updateOverlay(List<String> lines) async => overlayLines = lines;

  @override
  Future<void> hideOverlay() async => overlayVisible = false;
}

/// Microphone fed by the test.
class _FakeCapture implements AudioCapture {
  final controller = StreamController<Uint8List>.broadcast();
  AudioCaptureConfig? config;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<Stream<Uint8List>> start(AudioCaptureConfig config) async {
    this.config = config;
    return controller.stream;
  }

  @override
  Future<void> stop() async {}
}

void main() {
  late _FakeBackground background;
  late _FakeCapture capture;
  late ProviderContainer container;
  late bool permissionAsked;

  /// Builds a container around the fakes.
  ProviderContainer build() {
    final c = ProviderContainer(
      overrides: [
        backgroundCaptureProvider.overrideWithValue(background),
        audioCaptureProvider.overrideWithValue(capture),
        notificationPermissionProvider.overrideWithValue(
          () async => permissionAsked = true,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    background = _FakeBackground();
    capture = _FakeCapture();
    permissionAsked = false;
    container = build();
  });

  test('starts the service, the meeting mic and the overlay', () async {
    await container.read(soakProvider.notifier).toggle();

    final state = container.read(soakProvider);
    expect(state.running, isTrue);
    expect(state.overlayShown, isTrue);
    expect(permissionAsked, isTrue);
    expect(background.serviceRunning, isTrue);
    expect(capture.config?.source, CaptureSource.mic);
  });

  test(
    'counts segments, shows them in the overlay and measures gaps',
    () async {
      await container.read(soakProvider.notifier).toggle();

      capture.controller.add(pcm(1000, amplitude: 4000));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      capture.controller.add(pcm(700));
      await pumpEventQueue();

      final state = container.read(soakProvider);
      expect(state.segments, 1);
      expect(state.maxGapMs, greaterThanOrEqualTo(50));
      expect(background.overlayLines.single, '#1 · 1000 ms');
    },
  );

  test('stops everything when Stop is pressed in the notification', () async {
    await container.read(soakProvider.notifier).toggle();

    background.controller.add(const BackgroundStopPressed());
    await pumpEventQueue();

    expect(container.read(soakProvider).running, isFalse);
    expect(background.serviceRunning, isFalse);
    expect(background.overlayVisible, isFalse);
  });

  test('keeps lines long-pressed in the overlay', () async {
    await container.read(soakProvider.notifier).toggle();

    background.controller.add(const OverlayLineLongPressed('hello'));
    await pumpEventQueue();

    expect(container.read(soakProvider).savedLines, ['hello']);
  });

  test('runs without the overlay when its permission is denied', () async {
    background = _FakeBackground(overlayAllowed: false);
    container = build();

    await container.read(soakProvider.notifier).toggle();

    final state = container.read(soakProvider);
    expect(state.running, isTrue);
    expect(state.overlayDenied, isTrue);
    expect(background.serviceRunning, isTrue);
  });
}
