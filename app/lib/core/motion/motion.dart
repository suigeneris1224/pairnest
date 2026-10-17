import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';

/// Shared durations and curves so motion feels consistent across screens.
abstract final class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);
  static const curve = Curves.easeOutCubic;
  static const emphasized = Curves.easeInOutCubicEmphasized;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Fades and rises a child into place once, staggered by [index].
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 12});

  final Widget child;
  final int index;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.slow);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Motion.curve);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (Motion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    final delay = Duration(milliseconds: 50 * math.min(widget.index, 8));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _curve.value)), child: child),
      ),
    );
  }
}

/// A peso amount that counts smoothly from its previous value to the new one.
class AnimatedAmount extends StatefulWidget {
  const AnimatedAmount(this.value, {super.key, this.style, this.prefix = '', this.suffix = '', this.overflow});

  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final TextOverflow? overflow;

  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<AnimatedAmount> {
  late double _from = Motion.reduced(context) ? widget.value : 0;

  @override
  void didUpdateWidget(AnimatedAmount old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _from = old.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.value),
      duration: Motion.reduced(context) ? Duration.zero : Motion.slow * 1.5,
      curve: Motion.curve,
      builder: (context, v, _) => Text(
        '${widget.prefix}${peso(v.round())}${widget.suffix}',
        style: widget.style,
        overflow: widget.overflow,
        maxLines: widget.overflow == null ? null : 1,
      ),
    );
  }
}

/// Gives tappable surfaces a soft "press" squish.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (widget.enabled && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !Motion.reduced(context) ? 0.97 : 1,
        duration: Motion.fast,
        curve: Motion.curve,
        child: widget.child,
      ),
    );
  }
}
