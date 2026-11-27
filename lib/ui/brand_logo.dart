import 'package:material_ui/material_ui.dart';

/// Official eShokFix product mark, shared by setup and the dashboard.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.fit = BoxFit.contain});
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/eshokfix_logo.png',
    fit: fit,
    semanticLabel: 'eShokFix',
    filterQuality: FilterQuality.medium,
  );
}
