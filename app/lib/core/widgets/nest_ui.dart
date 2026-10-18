import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../mascot/mascot.dart';
import '../motion/motion.dart';
import '../theme/palettes.dart';
import 'categories.dart';
import 'common.dart';

/// Building blocks for the dashboard design's look: watercolor backdrop,
/// deep-green hero cards, pastel icon badges and soft section cards.

Color _darken(Color c, double t) => Color.lerp(c, Colors.black, t)!;

// ─── Backdrop ──────────────────────────────────────────────────────────────

/// Soft watercolor blobs and faint leaves behind a page's content.
class NestBackground extends StatelessWidget {
  const NestBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: _BackdropPainter(p.primary, p.accent, p.isDark))),
        ),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.green, this.warm, this.dark);

  final Color green, warm;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final a = dark ? 0.08 : 0.16;

    void blob(Offset c, double rx, double ry, Color color, double alpha) {
      final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    blob(Offset(w * 0.95, h * 0.04), w * 0.55, h * 0.16, green, a);
    blob(Offset(w * 0.02, h * 0.62), w * 0.45, h * 0.14, warm, a * 0.9);
    blob(Offset(w * 0.9, h * 0.92), w * 0.5, h * 0.12, green, a * 0.7);
    drawSprig(canvas, Offset(w * 0.02, h * 0.995), h * 0.16, green.withValues(alpha: dark ? 0.08 : 0.18), sway: 0.35);
    drawSprig(canvas, Offset(w * 0.98, h * 0.42), h * 0.08, green.withValues(alpha: dark ? 0.06 : 0.12), leanRight: false, sway: -0.6);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.green != green || old.warm != warm || old.dark != dark;
}

// ─── Hero card ─────────────────────────────────────────────────────────────

/// The deep-green gradient card used for each page's headline numbers.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20), this.tint});

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Optional base color instead of the palette's deep tone (e.g. lavender for feelings).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final base = tint ?? (p.isDark ? const Color(0xFF2E3D63) : p.primaryDeep);
    final radius = BorderRadius.circular(26);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(base, Colors.white, 0.06)!, _darken(base, 0.18)],
        ),
        boxShadow: [BoxShadow(color: base.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(right: -18, bottom: -34, child: _LeafWatermark(size: 104)),
            Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: IconTheme.merge(
                  data: const IconThemeData(color: Colors.white),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeafWatermark extends StatelessWidget {
  const _LeafWatermark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _WatermarkPainter()),
    ),
  );
}

class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Colors.white.withValues(alpha: 0.07);
    drawSprig(canvas, Offset(size.width * 0.4, size.height), size.height * 0.9, c, sway: 0.4);
    drawSprig(canvas, Offset(size.width * 0.6, size.height), size.height * 0.65, c, sway: 1.0);
  }

  @override
  bool shouldRepaint(_WatermarkPainter old) => false;
}

/// Outlined translucent pill used on hero cards (month picker etc.).
class HeroPill extends StatelessWidget {
  const HeroPill({super.key, required this.label, this.icon, this.onTap, this.trailing = Icons.expand_more_rounded});

  final String label;
  final IconData? icon;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.45))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: Colors.white), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 2), Icon(trailing, size: 18, color: Colors.white)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Light progress bar on a translucent track, for hero cards.
class HeroProgress extends StatelessWidget {
  const HeroProgress(this.value, {super.key, this.height = 10});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.18))),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
              duration: Motion.reduced(context) ? Duration.zero : Motion.slow * 1.5,
              curve: Motion.curve,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    color: value > 1 ? const Color(0xFFFFB4A8) : const Color(0xFFE9F1E4),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pastel badges and tiles ───────────────────────────────────────────────

/// The four pastel tones from the dashboard's quick actions.
enum Pastel {
  sage(Color(0xFFDCE8DD), Color(0xFF4E7D63)),
  sky(Color(0xFFD6E6F2), Color(0xFF3F6F94)),
  lavender(Color(0xFFE6DEF0), Color(0xFF6E5A97)),
  peach(Color(0xFFF9DCCD), Color(0xFFC2653F));

  const Pastel(this.light, this.deep);

  final Color light;
  final Color deep;

  Color background(PairnestPalette p) => p.isDark ? deep.withValues(alpha: 0.32) : light;
  Color foreground(PairnestPalette p) => p.isDark ? Color.lerp(deep, Colors.white, 0.55)! : deep;
}

class PastelIcon extends StatelessWidget {
  const PastelIcon(this.icon, {super.key, this.tone = Pastel.sage, this.size = 52});

  final IconData icon;
  final Pastel tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tone.background(p), shape: BoxShape.circle),
      child: Icon(icon, color: tone.foreground(p), size: size * 0.46),
    );
  }
}

/// Square quick-action card with a pastel icon.
class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.icon, required this.label, required this.tone, required this.onTap});

  final IconData icon;
  final String label;
  final Pastel tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PairnestCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
      child: Column(
        children: [
          PastelIcon(icon, tone: tone),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// A card with an icon + title header and an optional "View All ›" link.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.action = 'View All',
    this.onAction,
    this.color,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final String action;
  final VoidCallback? onAction;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return PairnestCard(
      color: color,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              // Half-width cards keep the title whole and show just a chevron.
              final compact = c.maxWidth < 200;
              return Row(
                children: [
                  if (icon != null) ...[Icon(icon, size: compact ? 18 : 20, color: p.primaryDeep), SizedBox(width: compact ? 6 : 8)],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: compact ? 14.5 : null),
                    ),
                  ),
                  if (onAction != null)
                    InkWell(
                      onTap: onAction,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!compact) Text(action, style: TextStyle(color: p.muted, fontSize: 12)),
                            Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─── Spending donut ────────────────────────────────────────────────────────

/// Donut of spending per category with a legend. Shows the five largest
/// categories and folds the rest into "Others".
class SpendingDonut extends StatelessWidget {
  const SpendingDonut({super.key, required this.spending, this.hideAmounts = false});

  final Map<String, double> spending;
  final bool hideAmounts;

  List<MapEntry<String, double>> get _slices {
    final sorted = spending.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length <= 5) return sorted;
    final rest = sorted.skip(4).fold<double>(0, (a, e) => a + e.value);
    return [...sorted.take(4), MapEntry('others', rest)];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final slices = _slices;
    final total = slices.fold<double>(0, (a, e) => a + e.value);
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No spending yet this month.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted),
        ),
      );
    }

    final donut = SizedBox.square(
      dimension: 118,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.reduced(context) ? Duration.zero : Motion.slow * 1.6,
        curve: Motion.emphasized,
        builder: (context, t, _) => Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 2,
                centerSpaceRadius: 37,
                pieTouchData: PieTouchData(enabled: false),
                sections: [
                  for (final e in slices)
                    PieChartSectionData(value: e.value * t, color: categoryStyle(e.key).color, radius: 20, showTitle: false),
                  // The unfilled remainder sweeps away as the chart animates in.
                  if (t < 1) PieChartSectionData(value: total * (1 - t), color: Colors.transparent, radius: 20, showTitle: false),
                ],
              ),
              duration: Duration.zero,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                hideAmounts
                    ? Text('₱••••', style: Theme.of(context).textTheme.titleMedium)
                    : AnimatedAmount(total, style: Theme.of(context).textTheme.titleMedium),
                Text('spent', style: TextStyle(color: p.muted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );

    Widget legend(bool compact) => Column(
      children: [
        for (final (i, e) in slices.indexed)
          FadeSlideIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  CircleAvatar(radius: 5, backgroundColor: categoryStyle(e.key).color),
                  const SizedBox(width: 8),
                  if (!compact) ...[CategoryIcon(e.key, size: 28), const SizedBox(width: 8)],
                  Expanded(
                    child: Text(
                      compact ? (categoryStyle(e.key).short ?? categoryStyle(e.key).label) : categoryStyle(e.key).label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  Text(hideAmounts ? '₱••••' : peso(e.value), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${(e.value / total * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11.5, color: p.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 290) return Column(children: [donut, const SizedBox(height: 12), legend(c.maxWidth < 260)]);
        // Beside the donut the legend is narrow: drop icons and use short labels.
        final legendWidth = c.maxWidth - 118 - 12;
        return Row(
          children: [
            donut,
            const SizedBox(width: 12),
            Expanded(child: legend(legendWidth < 250)),
          ],
        );
      },
    );
  }
}

// ─── Painted scenes (stand-ins for photos) ─────────────────────────────────

/// A soft painted landscape used where the design shows photos.
class SceneBanner extends StatelessWidget {
  const SceneBanner({super.key, required this.kind, this.height = 90, this.radius = 16});

  /// Goal icon key (`travel`, `home`, `shield`, …) or `date` for date nights.
  final String kind;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _ScenePainter(kind, p.primary, p.isDark)),
      ),
    );
  }
}

/// Sky colours (top, middle, horizon) and the sun or moon for each scene.
const _skies = <String, (Color, Color, Color, Color)>{
  'travel': (Color(0xFFBFE0EE), Color(0xFFDDEFF3), Color(0xFFF6EBDD), Color(0xFFFFF4DA)),
  'home': (Color(0xFFDDE7EE), Color(0xFFF4DCCB), Color(0xFFF6E7D6), Color(0xFFFFF3E2)),
  'shield': (Color(0xFFD5DEE6), Color(0xFFE7EEF0), Color(0xFFF3EEE2), Color(0xFFFFF0C9)),
  'car': (Color(0xFFD9E8F0), Color(0xFFEAF0EA), Color(0xFFF5EBD9), Color(0xFFFFF1D6)),
  'school': (Color(0xFF3E4A72), Color(0xFF7D7AA3), Color(0xFFEBC9B4), Color(0xFFFFF0D2)),
  'ring': (Color(0xFFF1D3DD), Color(0xFFF7DCCF), Color(0xFFFBEBDD), Color(0xFFFFF1E2)),
  'baby': (Color(0xFFF4D6E0), Color(0xFFF8E3E6), Color(0xFFFBF0EA), Color(0xFFFFF6E8)),
  'star': (Color(0xFFCFDCEB), Color(0xFFF2D9CB), Color(0xFFF8E6D2), Color(0xFFFFEFD4)),
  'pet': (Color(0xFFD6E9E4), Color(0xFFEAF1E4), Color(0xFFF6EEDC), Color(0xFFFFF3DA)),
  'business': (Color(0xFFDCE2F0), Color(0xFFEDE6EE), Color(0xFFF7EDE2), Color(0xFFFFF2DF)),
  'retire': (Color(0xFFF2B98F), Color(0xFFF6CFA6), Color(0xFFFBE4C4), Color(0xFFFFE8B8)),
  'date': (Color(0xFF3B3355), Color(0xFF7A5A6E), Color(0xFFE7A98C), Color(0xFFFFE2B8)),
};

/// A small illustrated scene for a goal: sky, hills and one clear subject,
/// in the birds' flat style, tinted to the couple's palette. Fine details
/// only appear on banners tall enough to show them.
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.kind, this.green, this.dark);

  final String kind;
  final Color green;
  final bool dark;

  static const _wood = Color(0xFF8A6A55);
  static const _cream = Color(0xFFFFF8EE);
  static const _coral = Color(0xFFD9826A);
  static const _ink = Color(0xFF4A3D58);

  /// Dark themes get the same scene in deeper, evening tones.
  Color _tone(Color c) => dark ? Color.lerp(c, const Color(0xFF1B2238), 0.4)! : c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final detail = h > 60;
    final full = Offset.zero & size;
    final night = kind == 'date';
    final (top, mid, horizon, sun) = _skies[kind] ?? _skies['star']!;
    Paint fill(Color c) => Paint()..color = _tone(c);

    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_tone(top), _tone(mid), _tone(horizon)],
        ).createShader(full),
    );

    // Sun, or a crescent moon for the night scenes.
    final sunAt = Offset(w * 0.74, h * 0.38);
    if (kind == 'baby' || kind == 'school') {
      canvas.drawCircle(sunAt, h * 0.13, fill(sun));
      canvas.drawCircle(sunAt + Offset(h * 0.06, -h * 0.03), h * 0.11, fill(kind == 'baby' ? mid : top));
    } else {
      canvas.drawCircle(sunAt, h * (kind == 'retire' ? 0.2 : 0.17), fill(sun));
    }
    if (detail && !night && kind != 'school') {
      _cloud(canvas, Offset(w * 0.18, h * 0.2), h * 0.07, fill(Colors.white.withValues(alpha: 0.85)));
      _cloud(canvas, Offset(w * 0.56, h * 0.14), h * 0.05, fill(Colors.white.withValues(alpha: 0.7)));
    }

    Path ridge(double base, double amp, double seed) {
      final path = Path()..moveTo(0, h);
      for (var i = 0; i <= 10; i++) {
        path.lineTo(w * i / 10, h * (base - amp * (0.5 + 0.5 * math.sin(i * 1.3 + seed))));
      }
      return path
        ..lineTo(w, h)
        ..close();
    }

    final farHill = Color.lerp(green, mid, 0.62)!;
    final nearHill = Color.lerp(green, Colors.white, 0.3)!;
    if (kind == 'travel' || kind == 'retire') {
      // Sea with a soft shine.
      canvas.drawRect(Rect.fromLTWH(0, h * 0.66, w, h * 0.34), fill(const Color(0xFF8EC5D6)));
      canvas.drawRect(Rect.fromLTWH(0, h * 0.66, w, h * 0.03), fill(Colors.white.withValues(alpha: 0.5)));
    } else if (night) {
      canvas.drawPath(ridge(0.72, 0.38, 0.5), fill(const Color(0xFF5B4A6A)));
      canvas.drawPath(ridge(0.82, 0.22, 2.1), fill(const Color(0xFF4A3D58)));
    } else {
      canvas.drawPath(ridge(0.74, 0.3, 0.5), fill(farHill));
      canvas.drawPath(ridge(0.86, 0.16, 2.1), fill(Color.lerp(farHill, green, 0.35)!));
      canvas.drawPath(ridge(1.02, 0.14, 4.0), fill(nearHill));
    }

    final s = h;
    switch (kind) {
      case 'travel':
        // Island with a snow-capped peak, a sailboat and a little plane.
        final peak = Offset(w * 0.66, h * 0.3);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.68)
            ..lineTo(peak.dx, peak.dy)
            ..lineTo(w * 0.84, h * 0.68)
            ..close(),
          fill(const Color(0xFF9FA8C8)),
        );
        canvas.drawPath(
          Path()
            ..moveTo(peak.dx - s * 0.07, peak.dy + s * 0.1)
            ..lineTo(peak.dx, peak.dy)
            ..lineTo(peak.dx + s * 0.07, peak.dy + s * 0.1)
            ..close(),
          fill(Colors.white),
        );
        final boat = Offset(w * 0.28, h * 0.8);
        canvas.drawPath(
          Path()
            ..moveTo(boat.dx - s * 0.16, boat.dy)
            ..lineTo(boat.dx + s * 0.16, boat.dy)
            ..lineTo(boat.dx + s * 0.11, boat.dy + s * 0.07)
            ..lineTo(boat.dx - s * 0.11, boat.dy + s * 0.07)
            ..close(),
          fill(_coral),
        );
        canvas.drawPath(
          Path()
            ..moveTo(boat.dx, boat.dy - s * 0.34)
            ..lineTo(boat.dx, boat.dy - s * 0.02)
            ..lineTo(boat.dx + s * 0.15, boat.dy - s * 0.02)
            ..close(),
          fill(_cream),
        );
        if (detail) _plane(canvas, Offset(w * 0.2, h * 0.3), s * 0.08, fill(_cream), fill(Colors.white.withValues(alpha: 0.8)));
      case 'home':
        final x = w * 0.26, y = h * 0.58, b = s * 0.26;
        if (detail) {
          canvas.drawRect(Rect.fromLTWH(x + b * 1.0, y - b * 0.75, b * 0.18, b * 0.45), fill(_wood));
          for (var i = 0; i < 3; i++) {
            canvas.drawCircle(
              Offset(x + b * 1.12 + i * b * 0.12, y - b * (0.95 + i * 0.22)),
              b * (0.08 + i * 0.03),
              fill(Colors.white.withValues(alpha: 0.75)),
            );
          }
        }
        canvas.drawRect(Rect.fromLTWH(x, y, b * 1.4, b), fill(_cream));
        canvas.drawPath(
          Path()
            ..moveTo(x - b * 0.18, y + b * 0.02)
            ..lineTo(x + b * 0.7, y - b * 0.62)
            ..lineTo(x + b * 1.58, y + b * 0.02)
            ..close(),
          fill(_coral),
        );
        canvas.drawRect(Rect.fromLTWH(x + b * 0.18, y + b * 0.4, b * 0.34, b * 0.6), fill(_wood));
        canvas.drawRect(Rect.fromLTWH(x + b * 0.82, y + b * 0.28, b * 0.36, b * 0.3), fill(const Color(0xFFFFD27A)));
        // Path to the door.
        canvas.drawPath(
          Path()
            ..moveTo(x + b * 0.2, y + b)
            ..lineTo(x + b * 0.5, y + b)
            ..lineTo(x + b * 0.9, h)
            ..lineTo(x - b * 0.2, h)
            ..close(),
          fill(const Color(0xFFF1E2CC)),
        );
        if (detail) {
          final post = fill(_cream.withValues(alpha: 0.9));
          for (var i = 0; i < 6; i++) {
            canvas.drawRect(Rect.fromLTWH(x + b * 1.75 + i * b * 0.22, y + b * 0.55, b * 0.07, b * 0.45), post);
          }
          canvas.drawRect(Rect.fromLTWH(x + b * 1.7, y + b * 0.7, b * 1.25, b * 0.06), post);
        }
      case 'shield':
        // A nest with two eggs, sheltered by a big leaf.
        final nest = Offset(w * 0.34, h * 0.8);
        canvas.drawPath(
          Path()
            ..moveTo(nest.dx, nest.dy - s * 0.42)
            ..quadraticBezierTo(nest.dx - s * 0.5, nest.dy - s * 0.5, nest.dx - s * 0.38, nest.dy - s * 0.22)
            ..quadraticBezierTo(nest.dx, nest.dy - s * 0.32, nest.dx + s * 0.38, nest.dy - s * 0.22)
            ..quadraticBezierTo(nest.dx + s * 0.5, nest.dy - s * 0.5, nest.dx, nest.dy - s * 0.42)
            ..close(),
          fill(green),
        );
        canvas.drawLine(
          Offset(nest.dx, nest.dy - s * 0.4),
          Offset(nest.dx + s * 0.03, nest.dy - s * 0.12),
          Paint()
            ..color = _tone(_wood)
            ..strokeWidth = s * 0.025,
        );
        canvas.drawOval(
          Rect.fromCenter(center: nest - Offset(0, s * 0.03), width: s * 0.46, height: s * 0.14),
          fill(const Color(0xFF6B4A3A)),
        );
        for (final dx in [-0.07, 0.07]) {
          canvas.drawOval(Rect.fromCenter(center: nest + Offset(dx * s, -s * 0.07), width: s * 0.13, height: s * 0.17), fill(_cream));
        }
        // Front rim of the nest, over the bottom of the eggs.
        canvas.drawPath(
          Path()
            ..moveTo(nest.dx - s * 0.25, nest.dy - s * 0.02)
            ..quadraticBezierTo(nest.dx, nest.dy + s * 0.04, nest.dx + s * 0.25, nest.dy - s * 0.02)
            ..quadraticBezierTo(nest.dx + s * 0.2, nest.dy + s * 0.12, nest.dx, nest.dy + s * 0.12)
            ..quadraticBezierTo(nest.dx - s * 0.2, nest.dy + s * 0.12, nest.dx - s * 0.25, nest.dy - s * 0.02)
            ..close(),
          fill(_wood),
        );
        if (detail) {
          final twig = Paint()
            ..color = _tone(const Color(0xFF6B4A3A))
            ..strokeWidth = s * 0.012;
          for (var i = -2; i <= 2; i++) {
            canvas.drawLine(nest + Offset(i * s * 0.08 - s * 0.05, -s * 0.02), nest + Offset(i * s * 0.08 + s * 0.05, s * 0.05), twig);
          }
          final drop = fill(const Color(0xFF9DC3D6));
          for (final (dx, dy) in [(0.08, 0.3), (0.13, 0.5), (0.05, 0.62), (0.6, 0.55)]) {
            canvas.drawOval(Rect.fromCenter(center: Offset(w * dx, h * dy), width: s * 0.025, height: s * 0.06), drop);
          }
        }
      case 'car':
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.05, h)
            ..quadraticBezierTo(w * 0.55, h * 0.86, w * 0.62, h * 0.66)
            ..lineTo(w * 0.66, h * 0.66)
            ..quadraticBezierTo(w * 0.7, h * 0.9, w * 0.5, h)
            ..close(),
          fill(const Color(0xFFB9B2A8)),
        );
        final car = Offset(w * 0.3, h * 0.76);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: car + Offset(0, -s * 0.11), width: s * 0.28, height: s * 0.14),
            Radius.circular(s * 0.06),
          ),
          fill(_coral),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: car + Offset(-s * 0.01, -s * 0.11), width: s * 0.2, height: s * 0.08),
            Radius.circular(s * 0.04),
          ),
          fill(const Color(0xFFDDEFF5)),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: car, width: s * 0.48, height: s * 0.14), Radius.circular(s * 0.06)),
          fill(_coral),
        );
        for (final dx in [-0.14, 0.14]) {
          canvas.drawCircle(car + Offset(dx * s, s * 0.07), s * 0.055, fill(const Color(0xFF3E3A44)));
          canvas.drawCircle(car + Offset(dx * s, s * 0.07), s * 0.022, fill(const Color(0xFFD8D3CC)));
        }
        if (detail) canvas.drawCircle(car + Offset(s * 0.22, -s * 0.01), s * 0.02, fill(const Color(0xFFFFE08A)));
      case 'school':
        if (detail) {
          for (final (dx, dy, r) in [(0.12, 0.18, 0.025), (0.3, 0.1, 0.018), (0.46, 0.24, 0.022), (0.9, 0.15, 0.02)]) {
            _star(canvas, Offset(w * dx, h * dy), s * r, fill(const Color(0xFFFFE6A3)));
          }
        }
        final book = Offset(w * 0.32, h * 0.78);
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(book.dx, book.dy - s * 0.04)
              ..quadraticBezierTo(book.dx + side * s * 0.12, book.dy - s * 0.1, book.dx + side * s * 0.25, book.dy - s * 0.06)
              ..lineTo(book.dx + side * s * 0.25, book.dy + s * 0.08)
              ..quadraticBezierTo(book.dx + side * s * 0.12, book.dy + s * 0.04, book.dx, book.dy + s * 0.1)
              ..close(),
            fill(_cream),
          );
        }
        canvas.drawLine(
          book + Offset(0, -s * 0.04),
          book + Offset(0, s * 0.1),
          Paint()
            ..color = _tone(_wood)
            ..strokeWidth = s * 0.015,
        );
        // Graduation cap above the book.
        final cap = Offset(book.dx, h * 0.45);
        canvas.drawRect(Rect.fromCenter(center: cap + Offset(0, s * 0.05), width: s * 0.16, height: s * 0.08), fill(_ink));
        canvas.drawPath(
          Path()
            ..moveTo(cap.dx - s * 0.2, cap.dy)
            ..lineTo(cap.dx, cap.dy - s * 0.08)
            ..lineTo(cap.dx + s * 0.2, cap.dy)
            ..lineTo(cap.dx, cap.dy + s * 0.08)
            ..close(),
          fill(const Color(0xFF2E2840)),
        );
        canvas.drawLine(
          cap,
          cap + Offset(s * 0.15, s * 0.1),
          Paint()
            ..color = _tone(brandYellow)
            ..strokeWidth = s * 0.015,
        );
        canvas.drawCircle(cap + Offset(s * 0.15, s * 0.12), s * 0.025, fill(brandYellow));
      case 'ring':
        // A flowered arch with two linked rings beneath it.
        final c = Offset(w * 0.34, h * 0.95);
        final arch = Rect.fromCenter(center: c, width: s * 0.9, height: s * 1.2);
        canvas.drawArc(
          arch,
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = _tone(green)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.06,
        );
        for (var i = 0; i <= 6; i++) {
          final a = math.pi + math.pi * i / 6;
          final at = c + Offset(math.cos(a) * s * 0.45, math.sin(a) * s * 0.6);
          canvas.drawCircle(at, s * 0.045, fill(i.isEven ? const Color(0xFFF2A7B5) : _cream));
        }
        final gold = Paint()
          ..color = _tone(brandYellow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.03;
        canvas.drawCircle(c + Offset(-s * 0.06, -s * 0.28), s * 0.09, gold);
        canvas.drawCircle(c + Offset(s * 0.06, -s * 0.28), s * 0.09, gold);
        if (detail) {
          for (final (dx, dy) in [(0.62, 0.35), (0.7, 0.6), (0.12, 0.45), (0.85, 0.75)]) {
            canvas.drawOval(
              Rect.fromCenter(center: Offset(w * dx, h * dy), width: s * 0.05, height: s * 0.03),
              fill(const Color(0xFFF2A7B5)),
            );
          }
        }
      case 'baby':
        // A hanging mobile: a star, a heart and a moon.
        final top0 = Offset(w * 0.34, 0);
        final bar = Offset(w * 0.34, h * 0.24);
        final line = Paint()
          ..color = _tone(_wood)
          ..strokeWidth = s * 0.012;
        canvas.drawLine(top0, bar, line);
        canvas.drawLine(bar - Offset(s * 0.28, 0), bar + Offset(s * 0.28, 0), line..strokeWidth = s * 0.02);
        line.strokeWidth = s * 0.01;
        for (final (dx, len, kind) in [(-0.26, 0.26, 0), (0.0, 0.36, 1), (0.26, 0.22, 2)]) {
          final hang = bar + Offset(dx * s, 0);
          final end = hang + Offset(0, len * s);
          canvas.drawLine(hang, end, line);
          switch (kind) {
            case 0:
              _star(canvas, end + Offset(0, s * 0.05), s * 0.07, fill(brandYellow));
            case 1:
              drawHeart(canvas, end + Offset(0, s * 0.06), s * 0.08, _tone(const Color(0xFFF2A7B5)));
            default:
              canvas.drawCircle(end + Offset(0, s * 0.05), s * 0.055, fill(const Color(0xFFB9C7EA)));
          }
        }
        if (detail) {
          // Crib rails along the bottom.
          final rail = fill(_cream);
          canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.82, w * 0.5, s * 0.04), rail);
          for (var i = 0; i <= 8; i++) {
            canvas.drawRect(Rect.fromLTWH(w * 0.1 + i * w * 0.06, h * 0.82, s * 0.025, h * 0.18), rail);
          }
        }
      case 'pet':
        final x = w * 0.24, y = h * 0.6, b = s * 0.26;
        canvas.drawRect(Rect.fromLTWH(x, y, b * 1.2, b), fill(_cream));
        canvas.drawPath(
          Path()
            ..moveTo(x - b * 0.15, y + b * 0.05)
            ..lineTo(x + b * 0.6, y - b * 0.55)
            ..lineTo(x + b * 1.35, y + b * 0.05)
            ..close(),
          fill(const Color(0xFFD9826A)),
        );
        canvas.drawPath(
          Path()
            ..moveTo(x + b * 0.32, y + b)
            ..lineTo(x + b * 0.32, y + b * 0.5)
            ..arcToPoint(Offset(x + b * 0.88, y + b * 0.5), radius: Radius.circular(b * 0.28))
            ..lineTo(x + b * 0.88, y + b)
            ..close(),
          fill(const Color(0xFF4A3B36)),
        );
        if (detail) {
          final paw = fill(Color.lerp(green, Colors.black, 0.25)!.withValues(alpha: 0.5));
          for (var i = 0; i < 3; i++) {
            _paw(canvas, Offset(x + b * (1.9 + i * 0.6), h * (0.92 - i * 0.08)), s * 0.035, paw);
          }
          _bone(canvas, Offset(x + b * 1.8, y + b * 0.35), s * 0.06, fill(_cream));
        }
      case 'business':
        final x = w * 0.2, y = h * 0.46, bw = s * 0.62, bh = s * 0.44;
        canvas.drawRect(Rect.fromLTWH(x, y, bw, bh), fill(_cream));
        canvas.drawRect(Rect.fromLTWH(x + bw * 0.12, y - s * 0.12, bw * 0.76, s * 0.1), fill(_ink));
        if (detail) {
          canvas.drawRect(Rect.fromLTWH(x + bw * 0.3, y - s * 0.085, bw * 0.4, s * 0.03), fill(brandYellow));
        }
        // Striped awning.
        const stripes = 5;
        for (var i = 0; i < stripes; i++) {
          canvas.drawPath(
            Path()
              ..moveTo(x + bw * i / stripes, y)
              ..lineTo(x + bw * (i + 1) / stripes, y)
              ..lineTo(x + bw * (i + 1) / stripes, y + s * 0.09)
              ..arcToPoint(Offset(x + bw * i / stripes, y + s * 0.09), radius: Radius.circular(bw / stripes / 2))
              ..close(),
            fill(i.isEven ? _coral : _cream),
          );
        }
        canvas.drawRect(Rect.fromLTWH(x + bw * 0.12, y + bh * 0.42, bw * 0.3, bh * 0.58), fill(_wood));
        canvas.drawRect(Rect.fromLTWH(x + bw * 0.52, y + bh * 0.38, bw * 0.36, bh * 0.32), fill(const Color(0xFFCFE6EF)));
      case 'retire':
        // Sand, a beach umbrella and a deck chair at sunset.
        canvas.drawPath(
          Path()
            ..moveTo(0, h * 0.82)
            ..quadraticBezierTo(w * 0.5, h * 0.74, w, h * 0.84)
            ..lineTo(w, h)
            ..lineTo(0, h)
            ..close(),
          fill(const Color(0xFFF1D9B0)),
        );
        final pole = Offset(w * 0.3, h * 0.9);
        canvas.drawLine(
          pole,
          pole - Offset(0, s * 0.5),
          Paint()
            ..color = _tone(_wood)
            ..strokeWidth = s * 0.022,
        );
        final canopy = Rect.fromCenter(center: pole - Offset(0, s * 0.5), width: s * 0.56, height: s * 0.36);
        for (var i = 0; i < 4; i++) {
          canvas.drawArc(canopy, math.pi + math.pi * i / 4, math.pi / 4, true, fill(i.isEven ? _coral : _cream));
        }
        final chair = Paint()
          ..color = _tone(_wood)
          ..strokeWidth = s * 0.02
          ..strokeCap = StrokeCap.round;
        final seat = Offset(w * 0.3 + s * 0.3, h * 0.88);
        canvas.drawLine(seat, seat + Offset(s * 0.18, -s * 0.18), chair);
        canvas.drawLine(seat + Offset(-s * 0.04, -s * 0.06), seat + Offset(s * 0.14, s * 0.02), chair);
        canvas.drawLine(seat + Offset(s * 0.1, -s * 0.1), seat + Offset(s * 0.18, s * 0.03), chair);
      case 'date':
        // Candles and a little heart on a table.
        canvas.drawRect(Rect.fromLTWH(0, h * 0.78, w, h * 0.22), fill(const Color(0xFF6B4A3A)));
        for (final x in [0.35, 0.55]) {
          canvas.drawRect(Rect.fromLTWH(w * x, h * 0.55, h * 0.07, h * 0.23), fill(const Color(0xFFFFF3E2)));
          canvas.drawOval(Rect.fromLTWH(w * x - h * 0.01, h * 0.43, h * 0.09, h * 0.12), fill(const Color(0xFFFFC46B)));
        }
        drawHeart(canvas, Offset(w * 0.78, h * 0.4), h * 0.14, _tone(const Color(0xFFEF8A7A)));
      default:
        // A sunrise star over the hills: any dream.
        _star(canvas, Offset(w * 0.34, h * 0.44), s * 0.16, fill(brandYellow));
        if (detail) {
          for (final (dx, dy) in [(0.18, 0.28), (0.5, 0.22)]) {
            _star(canvas, Offset(w * dx, h * dy), s * 0.04, fill(const Color(0xFFFFE6A3)));
          }
        }
    }
  }

  void _cloud(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawCircle(c, r, paint);
    canvas.drawCircle(c + Offset(r * 0.9, r * 0.2), r * 0.75, paint);
    canvas.drawCircle(c - Offset(r * 0.9, -r * 0.25), r * 0.65, paint);
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path..close(), paint);
  }

  void _plane(Canvas canvas, Offset c, double s, Paint body, Paint trail) {
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(c - Offset(s * (1.2 + i * 0.7), -s * 0.1 * i), s * 0.12, trail);
    }
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - s, c.dy)
        ..lineTo(c.dx + s, c.dy - s * 0.15)
        ..lineTo(c.dx + s * 1.2, c.dy)
        ..lineTo(c.dx - s, c.dy + s * 0.15)
        ..close(),
      body,
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - s * 0.1, c.dy)
        ..lineTo(c.dx - s * 0.5, c.dy - s * 0.7)
        ..lineTo(c.dx + s * 0.25, c.dy)
        ..close(),
      body,
    );
  }

  void _paw(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 1.6, height: r * 1.3), paint);
    for (final (dx, dy) in [(-0.9, -1.0), (-0.3, -1.4), (0.3, -1.4), (0.9, -1.0)]) {
      canvas.drawCircle(c + Offset(dx * r, dy * r), r * 0.38, paint);
    }
  }

  void _bone(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawRect(Rect.fromCenter(center: c, width: r * 2.4, height: r * 0.6), paint);
    for (final dx in [-1.2, 1.2]) {
      canvas.drawCircle(c + Offset(dx * r, -r * 0.3), r * 0.4, paint);
      canvas.drawCircle(c + Offset(dx * r, r * 0.3), r * 0.4, paint);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.kind != kind || old.green != green || old.dark != dark;
}

// ─── Quote card ────────────────────────────────────────────────────────────

const _quotes = [
  'Small steps build big dreams.',
  'Every peso saved is a promise kept.',
  'Better money, happier together.',
  'Little check-ins, big connection.',
  'Two hearts, one plan.',
  'Progress, not perfection.',
  'Dream big, budget together.',
];

/// A bird with a gentle daily quote.
class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final d = date ?? DateTime.now();
    final quote = _quotes[(d.difference(DateTime(d.year)).inDays) % _quotes.length];
    return PairnestCard(
      color: Color.lerp(p.surface, p.accent, p.isDark ? 0.05 : 0.08),
      padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
      child: Row(
        children: [
          MascotBird(size: 52, color: p.birdB),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“$quote”',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: p.text, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 4),
                Icon(Icons.favorite_border_rounded, size: 14, color: p.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty & loading states ────────────────────────────────────────────────

/// A friendly "nothing here yet" panel with the birds and an optional action.
/// Scrollable, so a surrounding [RefreshIndicator] still works when empty.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message, this.actionLabel, this.onAction, this.mood = MascotMood.idle});

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// [MascotMood.curious] has one bird gesture toward the action below.
  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return LayoutBuilder(
      builder: (context, c) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.hasBoundedHeight ? c.maxHeight : 0),
            child: Center(
              child: FadeSlideIn(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    MascotPair(width: 150, leaves: true, animate: true, mood: mood),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: p.heading),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.muted, height: 1.4),
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 18),
                      FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shares one shimmer sweep between every [Skeleton] beneath it.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final base = p.soft;
    final shine = Color.lerp(p.soft, p.surface, 0.7)!;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value * 3 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            colors: [base, shine, base],
            stops: const [0.35, 0.5, 0.65],
            begin: Alignment(-1 + t, -0.3),
            end: Alignment(1 + t, 0.3),
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// A rounded placeholder block; wrap a group in [SkeletonList] for the shimmer.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, required this.height, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: context.pn.soft, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// Loading placeholder shaped like a page: a hero card then [cards] list cards.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.cards = 3, this.hero = true, this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24)});

  final int cards;
  final bool hero;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    Widget row() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Skeleton(width: 40, height: 40, radius: 20),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Skeleton(width: 140, height: 12), SizedBox(height: 8), Skeleton(width: 90, height: 10)],
            ),
          ),
          Skeleton(width: 60, height: 12),
        ],
      ),
    );

    return Semantics(
      label: 'Loading',
      child: _Shimmer(
        child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          children: [
            if (hero) ...[const Skeleton(height: 150, radius: 24), const SizedBox(height: 18)],
            for (var i = 0; i < cards; i++) ...[
              PairnestCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(children: [row(), row()]),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Wallet card ───────────────────────────────────────────────────────────

/// The couple's shared money as a Pairnest e-wallet card: palette gradient,
/// wave pattern, chip and cardholder names. [child] is the
/// balance in the middle; [strip] (optional) tucks under the card's bottom edge.
class WalletCard extends StatefulWidget {
  const WalletCard({
    super.key,
    required this.child,
    required this.holder,
    required this.number,
    this.title = 'Our Card',
    this.trailing,
    this.strip,
    this.onTap,
    this.colors,
    this.accent,
    this.emblem,
    this.corner,
  });

  final Widget child;

  /// Bottom-right, where a real card puts its network logo.
  final Widget? corner;

  /// Top-left name, e.g. "Our Card" or a bank's name.
  final String title;

  /// Light, base and dark gradient stops; the theme's colour when null.
  final List<Color>? colors;

  /// A thin stripe along the top in a brand's second colour.
  final Color? accent;

  /// Replaces the chip and contactless mark, e.g. a phone for e-wallets.
  final Widget? emblem;

  /// Cardholder line, e.g. "ALEX & SAM".
  final String holder;

  /// Short card number shown as "•••• 0001".
  final String number;

  /// Top-right control, such as the month pill.
  final Widget? trailing;
  final Widget? strip;
  final VoidCallback? onTap;

  /// Bank cards are 85.6 × 54 mm.
  static const ratio = 1.586;
  static const minHeight = 222.0;
  static const _tuck = 18.0;

  @override
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  bool _pressed = false;

  void _press(bool down) {
    if (widget.onTap != null && !Motion.reduced(context)) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final height = math.max(c.maxWidth / WalletCard.ratio, WalletCard.minHeight);
        final card = SizedBox(height: height, child: _face(context));
        if (widget.strip == null) return card;
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(10, height - WalletCard._tuck, 10, 0),
              child: _Strip(child: widget.strip!),
            ),
            card,
          ],
        );
      },
    );
  }

  Widget _face(BuildContext context) {
    final p = context.pn;
    final base = widget.colors?[1] ?? (p.isDark ? const Color(0xFF2E3D63) : p.primaryDeep);
    final stops = widget.colors ?? [Color.lerp(base, Colors.white, 0.14)!, base, _darken(base, 0.28)];
    final radius = BorderRadius.circular(22);
    const soft = TextStyle(color: Color(0xDDFFFFFF), fontSize: 11.5, letterSpacing: 1.6, fontWeight: FontWeight.w600);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: Motion.fast,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: stops, stops: const [0, 0.45, 1]),
            boxShadow: [BoxShadow(color: base.withValues(alpha: 0.32), blurRadius: 24, offset: const Offset(0, 12))],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                const Positioned.fill(child: CustomPaint(painter: _WavePainter())),
                if (widget.accent != null) Positioned(top: 0, left: 0, right: 0, height: 5, child: ColoredBox(color: widget.accent!)),
                // Diagonal sheen, like light across a card.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-1, -1),
                        end: const Alignment(0.2, 0.4),
                        colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Colors.white),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                              ),
                            ),
                            if (widget.trailing != null) ...[
                              const SizedBox(width: 8),
                              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 170), child: widget.trailing),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        widget.emblem ??
                            Row(
                              children: [
                                const SizedBox(width: 36, height: 27, child: CustomPaint(painter: _ChipPainter())),
                                const SizedBox(width: 10),
                                Icon(Icons.contactless_outlined, size: 22, color: Colors.white.withValues(alpha: 0.85)),
                              ],
                            ),
                        const SizedBox(height: 4),
                        Expanded(child: widget.child),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.number.isNotEmpty) ...[
                                    Text('•••• ${widget.number}', style: soft.copyWith(fontSize: 11, letterSpacing: 2)),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    widget.holder,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: soft.copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.corner != null) ...[
                              const SizedBox(width: 8),
                              // Never taller than the holder lines, so the card can't overflow.
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180, maxHeight: 28),
                                child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomRight, child: widget.corner),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The stats panel that tucks under a [WalletCard], like a card in its sleeve.
class _Strip extends StatelessWidget {
  const _Strip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, WalletCard._tuck + 12, 16, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}

/// Faint guilloché-style waves across the card.
class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.07);
    for (var i = 0; i < 9; i++) {
      final path = Path();
      final y0 = size.height * (0.35 + i * 0.075);
      for (var x = 0.0; x <= size.width; x += 4) {
        final y = y0 + math.sin(x / size.width * math.pi * 2 + i * 0.6) * (10 + i * 1.5);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A gold contact chip.
class _ChipPainter extends CustomPainter {
  const _ChipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3DC9A), Color(0xFFD4AA52), Color(0xFFEFD08A)],
        ).createShader(Offset.zero & size),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x66704F12);
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(0, h / 3), Offset(w * 0.32, h / 3), line);
    canvas.drawLine(Offset(0, h * 2 / 3), Offset(w * 0.32, h * 2 / 3), line);
    canvas.drawLine(Offset(w * 0.68, h / 3), Offset(w, h / 3), line);
    canvas.drawLine(Offset(w * 0.68, h * 2 / 3), Offset(w, h * 2 / 3), line);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.32, h * 0.18, w * 0.36, h * 0.64), const Radius.circular(3)), line);
    canvas.drawRRect(rect, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
