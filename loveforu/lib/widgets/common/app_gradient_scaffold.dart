import 'package:flutter/material.dart';

import 'package:loveforu/theme/app_gradients.dart';

/// Shared scaffold that applies the app gradient and optional padding/safe-area.
class AppGradientScaffold extends StatelessWidget {
  const AppGradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.padding,
    this.extendBodyBehindAppBar = false,
    this.safeArea = true,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final EdgeInsetsGeometry? padding;
  final bool extendBodyBehindAppBar;
  final bool safeArea;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    if (safeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: content,
      ),
    );
  }
}
