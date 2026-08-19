import 'dart:ui';

import 'package:flutter/material.dart';

/// A frosted-glass panel over the [AeolusBackground]: blurred translucent
/// fill, a hairline gold edge, and a faint gold glow — used everywhere a
/// plain `Card` would otherwise sit flat on the page.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.10),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          // Material widgets placed directly inside this card (ListTile,
          // IconButton, etc.) need a Material ancestor to paint their
          // background/ink splashes correctly -- without one, those effects
          // are silently invisible rather than erroring at runtime (Flutter
          // only flags it as a debug-mode assertion). `transparency` adds
          // that ancestor without drawing a surface of its own, since this
          // card already provides its own decoration above.
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}
