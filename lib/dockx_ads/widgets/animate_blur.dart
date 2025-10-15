import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

class AnimatedBlur extends StatelessWidget {
  final Widget child;
  final double sigma;
  final int durationMs;
  const AnimatedBlur({
    required this.child,
    required this.sigma,
    required this.durationMs,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: sigma),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        if (value == 0) return child!;
        // Clip so the blur doesn't bleed outside the container
        return ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: value, sigmaY: value),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
