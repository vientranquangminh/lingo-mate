import 'dart:async';

import 'package:lingo_mate/core/background/background_capture.dart';

/// Records service and overlay calls; the test pushes notification and overlay events.
class FakeBackground implements BackgroundCapture {
  FakeBackground({this.overlayAllowed = true});

  bool overlayAllowed;
  final controller = StreamController<BackgroundEvent>.broadcast();
  bool serviceRunning = false;
  bool overlayVisible = false;
  int overlaySettingsOpened = 0;
  List<OverlayLine> overlayLines = const [];
  String overlayEngine = '';
  String overlayEngineLabel = '';

  @override
  Stream<BackgroundEvent> get events => controller.stream;

  @override
  Future<void> startService() async => serviceRunning = true;

  @override
  Future<void> stopService() async => serviceRunning = false;

  @override
  Future<bool> canDrawOverlays() async => overlayAllowed;

  @override
  Future<void> openOverlaySettings() async => overlaySettingsOpened++;

  @override
  Future<bool> showOverlay() async => overlayVisible = overlayAllowed;

  @override
  Future<void> updateOverlay(
    List<OverlayLine> lines, {
    String engine = '',
    String engineLabel = '',
  }) async {
    overlayLines = lines;
    overlayEngine = engine;
    overlayEngineLabel = engineLabel;
  }

  @override
  Future<void> hideOverlay() async => overlayVisible = false;
}
