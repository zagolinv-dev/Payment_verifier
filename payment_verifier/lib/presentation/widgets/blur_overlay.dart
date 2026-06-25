import 'dart:ui';
import 'package:flutter/material.dart';

class BlurOverlay extends StatelessWidget {
  const BlurOverlay({
    super.key,
    required this.child,
    this.sigma = 6,
    this.opacity = 0.35,
  });

  final Widget child;
  final double sigma;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(color: Colors.transparent),
        ),
        Container(color: Colors.black.withOpacity(opacity)),
        Center(child: child),
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
    barrierColor: Colors.transparent,
    builder: (ctx) => BlurOverlay(child: builder(ctx)),
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
    barrierColor: Colors.transparent,
    builder: (ctx) => BlurOverlay(
      sigma: 4,
      opacity: 0.25,
      child: builder(ctx),
    ),
  );
}
