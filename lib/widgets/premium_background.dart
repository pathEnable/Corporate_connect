
import 'package:flutter/material.dart';

class PremiumBackground extends StatelessWidget {
  final Widget child;
  final bool showPattern;

  const PremiumBackground({
    super.key,
    required this.child,
    this.showPattern = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Base Background
        Positioned.fill(
          child: Container(
            color: isDark ? theme.scaffoldBackgroundColor : theme.scaffoldBackgroundColor,
          ),
        ),

        // Animated / Static Gradient Blobs
        if (isDark) ...[
          Positioned(
            top: -100,
            right: -50,
            child: _GradientBlob(
              color: const Color(0xFF26E9CF).withValues(alpha: 0.12),
              size: 400,
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: _GradientBlob(
              color: const Color(0xFF1AA18E).withValues(alpha: 0.08),
              size: 350,
            ),
          ),
        ] else ...[
          Positioned(
            top: -50,
            right: -50,
            child: _GradientBlob(
              color: const Color(0xFF26E9CF).withValues(alpha: 0.08),
              size: 300,
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: _GradientBlob(
              color: const Color(0xFF1AA18E).withValues(alpha: 0.05),
              size: 250,
            ),
          ),
        ],

        // Optional Pattern Overlay
        if (showPattern)
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.02 : 0.04,
              child: CustomPaint(
                painter: _GridPatternPainter(color: theme.colorScheme.onSurface),
              ),
            ),
          ),

        // Main Content
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GradientBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GradientBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  final Color color;
  _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const spacing = 30.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
