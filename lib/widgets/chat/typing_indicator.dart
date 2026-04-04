
import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.onSurface.withAlpha(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDots(),
                    const SizedBox(width: 10),
                    Text(
                      'En train d\'écrire',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary.withAlpha(200),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            double value = (_controller.value - delay) % 1.0;
            if (value < 0) value += 1.0;
            
            double opacity = 0.3;
            double scale = 1.0;
            
            if (value < 0.3) {
              opacity = 0.3 + (value / 0.3) * 0.7;
              scale = 1.0 + (value / 0.3) * 0.3;
            } else if (value < 0.6) {
              opacity = 1.0 - ((value - 0.3) / 0.3) * 0.7;
              scale = 1.3 - ((value - 0.3) / 0.3) * 0.3;
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha((opacity * 255).toInt()),
                shape: BoxShape.circle,
              ),
              transform: Matrix4.diagonal3Values(scale, scale, 1.0),
            );
          },
        );
      }),
    );
  }
}
