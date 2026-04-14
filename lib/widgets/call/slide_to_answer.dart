import 'package:flutter/material.dart';

class SlideToAnswer extends StatefulWidget {
  final VoidCallback onAnswer;
  final VoidCallback onDecline;
  final bool isVideo;

  const SlideToAnswer({
    super.key,
    required this.onAnswer,
    required this.onDecline,
    this.isVideo = false,
  });

  @override
  State<SlideToAnswer> createState() => _SlideToAnswerState();
}

class _SlideToAnswerState extends State<SlideToAnswer> {
  double _dragPosition = 0.0;
  final double _maxWidth = 300.0;
  final double _buttonSize = 64.0;
  
  bool _answered = false;

  void _onPanUpdate(DragUpdateDetails details) {
    if (_answered) return;
    setState(() {
      _dragPosition += details.delta.dx;
      if (_dragPosition < 0) _dragPosition = 0;
      if (_dragPosition > _maxWidth - _buttonSize) {
        _dragPosition = _maxWidth - _buttonSize;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_answered) return;
    if (_dragPosition > (_maxWidth - _buttonSize) * 0.7) {
      setState(() {
        _dragPosition = _maxWidth - _buttonSize;
        _answered = true;
      });
      widget.onAnswer();
    } else {
      setState(() {
        _dragPosition = 0.0; // Snap back
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              width: _maxWidth,
              height: _buttonSize,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(_buttonSize / 2),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(left: _buttonSize), // Offset text
                  child: Text(
                     _answered ? 'Connexion en cours...' : 'Glisser pour répondre',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: _answered ? 1.0 : 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: _dragPosition,
              child: GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  width: _buttonSize,
                  height: _buttonSize,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isVideo ? Icons.videocam : Icons.call,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: widget.onDecline,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                 BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.call_end, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Refuser', 
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
