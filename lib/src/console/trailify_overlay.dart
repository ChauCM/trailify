import 'package:flutter/material.dart';
import 'trailify_auth_screen.dart';

class TrailifyOverlay extends StatelessWidget {
  const TrailifyOverlay._internal({Key? key}) : super(key: key);

  static void attach(BuildContext context) {
    final entry = OverlayEntry(
      builder: (context) {
        return const TrailifyOverlay._internal();
      },
    );

    Future.delayed(kThemeAnimationDuration, () {
      final overlay = Overlay.of(context);
      overlay.insert(entry);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _DraggableTrailifyFAB();
  }
}

class _DraggableTrailifyFAB extends StatefulWidget {
  const _DraggableTrailifyFAB({Key? key}) : super(key: key);

  @override
  State<_DraggableTrailifyFAB> createState() => _DraggableTrailifyFABState();
}

class _DraggableTrailifyFABState extends State<_DraggableTrailifyFAB>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  late final AnimationController _animationController;
  Animation<Offset>? _animation;
  Offset _offset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        setState(() {
          _offset =
              Offset(size.width - 52.0 - 12.0, (size.height / 2) - 12.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updatePosition(DragUpdateDetails details) {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    setState(() {
      _offset = Offset(
        (_offset.dx + details.delta.dx).clamp(0, size.width - 52.0),
        (_offset.dy + details.delta.dy).clamp(0, size.height - 52.0),
      );
    });
  }

  void _snapToEdge(DragEndDetails details) {
    final size = MediaQuery.of(context).size;
    const buttonWidth = 52.0;
    const edgeMargin = 12.0;

    final distanceToLeft = _offset.dx;
    final distanceToRight = size.width - (_offset.dx + buttonWidth);

    final targetX = distanceToLeft < distanceToRight
        ? edgeMargin
        : size.width - buttonWidth - edgeMargin;

    _animation = Tween<Offset>(
      begin: _offset,
      end: Offset(targetX, _offset.dy),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    ))
      ..addListener(() {
        if (mounted) {
          setState(() {
            _offset = _animation!.value;
          });
        }
      });

    _animationController.reset();
    _animationController.forward();
    setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: GestureDetector(
          onPanStart: (_) => setState(() => _isDragging = true),
          onPanUpdate: _updatePosition,
          onPanEnd: _snapToEdge,
          child: _TrailifyFAB(onTapAllowed: !_isDragging),
        ),
      ),
    );
  }
}

class _TrailifyFAB extends StatefulWidget {
  final bool onTapAllowed;

  const _TrailifyFAB({Key? key, this.onTapAllowed = true}) : super(key: key);

  @override
  _TrailifyFABState createState() => _TrailifyFABState();
}

class _TrailifyFABState extends State<_TrailifyFAB> {
  bool _isOpened = false;

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _onPressed() async {
    if (!widget.onTapAllowed) return;

    if (_isOpened) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const TrailifyAuthScreen(),
          settings: const RouteSettings(name: '/trailify_auth'),
        ),
      );
    }

    setState(() => _isOpened = !_isOpened);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onPressed,
      child: AnimatedContainer(
        duration: kThemeAnimationDuration,
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _isOpened ? Colors.red : Colors.lightBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          _isOpened ? Icons.close : Icons.terminal,
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }
}
