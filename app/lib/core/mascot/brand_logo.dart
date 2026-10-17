import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/palettes.dart';

/// The official Pairnest logo (birds + wordmark). The artwork has a cream
/// background, so on dark themes it sits on a rounded cream card.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 220, this.animateIn = false});

  final double width;

  /// Fade and gently scale in on first show (splash).
  final bool animateIn;

  static const asset = 'assets/brand/logo_full.png';

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    Widget logo = Image.asset(asset, width: width, semanticLabel: 'Pairnest', filterQuality: FilterQuality.medium);
    if (p.isDark) {
      logo = Container(
        padding: EdgeInsets.all(width * 0.06),
        decoration: BoxDecoration(color: const Color(0xFFFEF9F1), borderRadius: BorderRadius.circular(width * 0.12)),
        child: logo,
      );
    }
    if (!animateIn || Motion.reduced(context)) return logo;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow * 1.4,
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.88 + 0.12 * t, child: child),
      ),
      child: logo,
    );
  }
}
