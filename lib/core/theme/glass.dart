import 'dart:ui';

import 'package:flutter/material.dart';

/// Glassmorphism surface used across the dashboard and dhikr pages:
/// frosted blur, soft gradient tint, and a hairline gold-accent border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.gradient,
    this.borderOpacity = 0.35,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(28);
    final defaultGradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        scheme.primary.withValues(alpha: 0.10),
        scheme.secondary.withValues(alpha: 0.06),
      ],
    );

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: gradient ?? defaultGradient,
                  color: scheme.surface.withValues(alpha: 0.55),
                  border: Border.all(
                    color: scheme.secondary.withValues(alpha: borderOpacity),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative eight-pointed Islamic star built from two rotated squares,
/// used as a subtle premium motif on empty states and the splash area.
class IslamicStar extends StatelessWidget {
  const IslamicStar({super.key, this.size = 64, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = (color ?? Theme.of(context).colorScheme.secondary)
        .withValues(alpha: 0.75);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final angle in [0.0, 0.7853981634]) // 0°, 45°
            Transform.rotate(
              angle: angle,
              child: Container(
                width: size * 0.72,
                height: size * 0.72,
                decoration: BoxDecoration(
                  border: Border.all(color: c, width: 1.4),
                  borderRadius: BorderRadius.circular(size * 0.12),
                ),
              ),
            ),
          Container(width: size * 0.14, height: size * 0.14,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}
