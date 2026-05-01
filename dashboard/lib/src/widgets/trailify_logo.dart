import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TrailifyLogo extends StatelessWidget {
  final double size;

  const TrailifyLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logo.svg',
      width: size,
      height: size,
    );
  }
}
