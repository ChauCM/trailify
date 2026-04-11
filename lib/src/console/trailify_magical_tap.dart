import 'package:flutter/material.dart';
import '../trailify.dart';

class TrailifyMagicalTap extends StatefulWidget {
  final Widget child;
  final HitTestBehavior behavior;

  const TrailifyMagicalTap({
    Key? key,
    required this.child,
    this.behavior = HitTestBehavior.translucent,
  }) : super(key: key);

  @override
  State<TrailifyMagicalTap> createState() => _TrailifyMagicalTapState();
}

class _TrailifyMagicalTapState extends State<TrailifyMagicalTap> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: () {
        _count++;
        if (_count == 10) {
          _count = 0;
          Trailify.instance.openConsole(context);
        }
      },
      child: widget.child,
    );
  }
}
