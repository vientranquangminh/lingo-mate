import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// Scaffold that also sets the system bar style and wraps the page in a [PopScope].
class AppPlatformScaffold extends StatelessWidget {
  const AppPlatformScaffold({
    super.key,
    this.brightness,
    this.backgroundColor,
    this.body,
    this.appBar,
    this.resizeToAvoidBottomInset,
    this.extendBody,
    this.extendBodyBehindAppBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.floatingActionButtonLocation,
    this.bottomSheet,
    this.canPop = true,
    this.onPopInvokedWithResult,
  });

  final Brightness? brightness;
  final Color? backgroundColor;
  final Widget? body;
  final PreferredSizeWidget? appBar;
  final bool? resizeToAvoidBottomInset;
  final bool? extendBody;
  final bool? extendBodyBehindAppBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomSheet;

  /// PopScope properties
  ///
  final bool canPop;
  final Function(bool, dynamic)? onPopInvokedWithResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = this.brightness ?? theme.brightness;
    final backgroundColor =
        this.backgroundColor ?? theme.scaffoldBackgroundColor;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: onPopInvokedWithResult,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarBrightness: (Platform.isAndroid) ? null : brightness,
          statusBarIconBrightness: (Platform.isIOS)
              ? null
              : (brightness == Brightness.dark)
              ? Brightness.light
              : Brightness.dark,
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: body,
          appBar: appBar,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          extendBody: extendBody ?? false,
          extendBodyBehindAppBar: extendBodyBehindAppBar ?? false,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButtonLocation: floatingActionButtonLocation,
          bottomSheet: bottomSheet,
        ),
      ),
    );
  }
}
