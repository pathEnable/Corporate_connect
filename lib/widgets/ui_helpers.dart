import 'package:flutter/material.dart';

/// Widget de chargement "shimmer" réutilisable pour les listes.
class ShimmerLoading extends StatefulWidget {
  final int itemCount;
  const ShimmerLoading({super.key, this.itemCount = 6});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              _shimmerBox(56, 56, theme, isCircle: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(14, 160, theme),
                    const SizedBox(height: 10),
                    _shimmerBox(10, 240, theme),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(double height, double width, ThemeData theme, {bool isCircle = false}) {
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.onSurface.withAlpha(20);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: isCircle ? null : BorderRadius.circular(8),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              (_animation.value - 0.3).clamp(0.0, 1.0),
              _animation.value.clamp(0.0, 1.0),
              (_animation.value + 0.3).clamp(0.0, 1.0),
            ],
            colors: [
              baseColor,
              highlightColor,
              baseColor,
            ],
          ),
        ),
      ),
    );
  }
}

/// Transition de page avec effet de fondu + glissement.
class FadeSlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeSlideRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.05);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOut));
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: animation.drive(tween),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}
