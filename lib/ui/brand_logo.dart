import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official eShokFix product mark, shared by setup and the dashboard.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.fit = BoxFit.contain});
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/branding/eshokfix_logo.svg',
    fit: fit,
    semanticsLabel: 'eShokFix',
  );
}
