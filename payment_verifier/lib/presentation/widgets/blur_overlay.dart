import 'dart:ui';
import 'package:flutter/material.dart';

class BlurOverlay extends StatelessWidget {
  const BlurOverlay({
    super.key,
    required this.child,
    this.sigma = 6,
    this.opacity = 0.35,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final double sigma;
  final double opacity;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(color: Colors.black.withOpacity(opacity * 0.4)),
        ),
        Container(color: Colors.black.withOpacity(opacity)),
        Align(alignment: alignment, child: child),
      ],
    );
  }
}

Future<T?> showBlurredDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: builder(ctx),
    ),
  );
}

Future<T?> showBlurredBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => builder(ctx),
  );
}
