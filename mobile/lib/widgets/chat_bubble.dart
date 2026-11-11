import 'package:flutter/material.dart';

import '../theme.dart';

/// The message bubble of the Hacky chat and of chat threads, like the web's
/// (web/src/hacky.css .hk-bubble): grey with the tail at the bottom left for
/// theirs, blue with the tail at the bottom right for mine.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.child, this.mine = false});

  final Widget child;
  final bool mine;

  /// The text inside a bubble.
  static TextStyle textStyle({bool mine = false}) => TextStyle(
    color: mine ? AppColors.outgoingText : AppColors.ink,
    fontSize: 15.5,
    height: 1.45,
  );

  static const _round = Radius.circular(20);
  static const _tailCorner = Radius.circular(6);

  @override
  Widget build(BuildContext context) {
    final color = mine ? AppColors.outgoingBubble : AppColors.incomingBubble;
    return CustomPaint(
      painter: _BubbleTail(color: color, mine: mine),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: _round,
            topRight: _round,
            bottomLeft: mine ? _round : _tailCorner,
            bottomRight: mine ? _tailCorner : _round,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// The little tail: the web's 12×14 box that sticks 5px out of the bubble's
/// bottom corner, clipped to polygon(45% 0, 100% 0, 100% 100%, 0 100%,
/// 35% 65%) and mirrored for my bubbles.
class _BubbleTail extends CustomPainter {
  const _BubbleTail({required this.color, required this.mine});

  final Color color;
  final bool mine;

  static const _width = 12.0;
  static const _height = 14.0;
  static const _overhang = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final left = mine ? size.width - _width + _overhang : -_overhang;
    final top = size.height - _height;
    Offset at(double x, double y) =>
        Offset(left + (mine ? 1 - x : x) * _width, top + y * _height);
    final start = at(0.45, 0);
    final path = Path()..moveTo(start.dx, start.dy);
    for (final point in [at(1, 0), at(1, 1), at(0, 1), at(0.35, 0.65)]) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubbleTail oldDelegate) =>
      oldDelegate.color != color || oldDelegate.mine != mine;
}
