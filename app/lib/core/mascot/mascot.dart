import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/palettes.dart';
import 'mascot_controller.dart';

export 'mascot_controller.dart';

/// Logo yellow, shared by the heart, beaks and feet.
const brandYellow = Color(0xFFF5B82E);
const _beakYellow = Color(0xFFF2B33D);
const _cream = Color(0xFFFBF3DC);

/// How one bird is posed for a frame. Every field defaults to neutral, so
/// `BirdPose.neutral` is the bird standing still with its eyes open.
@immutable
class BirdPose {
  const BirdPose({
    this.breathe = 0,
    this.headTilt = 0,
    this.eyeOpen = 1,
    this.joy = 0,
    this.gaze = Offset.zero,
    this.wingLift = 0,
    this.thoughtful = 0,
  });

  static const neutral = BirdPose();

  /// -1…1: squash (negative) or stretch the body a little, feet pinned.
  final double breathe;

  /// Radians: the head (face, eyes, beak, tufts) tilts; the body stays put.
  final double headTilt;

  /// 1 open, 0 shut: blinks.
  final double eyeOpen;

  /// 0…1: open eyes cross-fade into the logo's happy "^ ^".
  final double joy;

  /// -1…1 on each axis: where the eyes look.
  final Offset gaze;

  /// 0…1: the wing lifts away from the body (flaps, gestures).
  final double wingLift;

  /// 0…1: eyes look up and aside, brows lift, the smile flattens.
  final double thoughtful;
}

/// The Pairnest bird couple from the logo, drawn in code so it re-tints with
/// the couple's palette.
///
/// With [animate] the pair idles: each bird breathes on its own rhythm,
/// blinks at natural intervals, now and then tilts its head, and both lean
/// in toward each other while the heart drifts. [mood] blends in a lasting
/// expression, and a [controller] triggers one-off reactions. Under reduced
/// motion the birds hold still and only their faces change.
class MascotPair extends StatefulWidget {
  const MascotPair({
    super.key,
    this.width = 220,
    this.heart = true,
    this.leaves = true,
    this.bubbles = false,
    this.animate = false,
    this.branch = false,
    this.mood = MascotMood.idle,
    this.controller,
    this.playOnMount,
  });

  final double width;
  final bool heart;
  final bool leaves;
  final bool bubbles;

  /// Run the idle loop.
  final bool animate;

  /// Perch the pair on a leafy branch, as in the dashboard header.
  final bool branch;

  final MascotMood mood;

  /// Plays a [MascotReaction] whenever [MascotController.react] is called.
  final MascotController? controller;

  /// A reaction to play once when the birds first appear (e.g. a celebration).
  final MascotReaction? playOnMount;

  @override
  State<MascotPair> createState() => MascotPairState();
}

/// Smooth 0→1→0 envelope: rises over [a]…[b], holds, falls over [c]…[d].
double _bump(double x, double a, double b, double c, double d) {
  if (x <= a || x >= d) return 0;
  if (x < b) return Curves.easeInOut.transform((x - a) / (b - a));
  if (x <= c) return 1;
  return 1 - Curves.easeInOut.transform((x - c) / (d - c));
}

/// One bird's idle clock: breathing phase, blinks and head tilts.
class _BirdClock {
  _BirdClock(this.breathPeriod, this.random, {required double firstBlink, required double firstTilt})
    : nextBlink = firstBlink,
      nextTilt = firstTilt;

  final double breathPeriod;
  final math.Random random;
  double phase = 0;
  double nextBlink;
  double blinkAt = -10;
  bool doubleBlink = false;
  double nextTilt;
  double tiltAt = -100;
  double tiltHold = 1.5;
  double tiltSign = 1;
  int blinks = 0;

  static const blinkLength = 0.14;
  static const tiltIn = 0.9;

  void advance(double t, double dt, double slow) {
    phase += dt * 2 * math.pi / (breathPeriod * slow);
    if (t >= nextBlink) {
      blinkAt = t;
      blinks++;
      // Now and then a quick double blink.
      doubleBlink = !doubleBlink && random.nextDouble() < 0.18;
      nextBlink = t + (doubleBlink ? 0.26 : 2.8 + random.nextDouble() * 3.7);
    }
  }

  /// 1 open … 0 shut: a fast close and a slightly slower open.
  double eyeOpen(double t) {
    final x = (t - blinkAt) / blinkLength;
    if (x < 0 || x > 1) return 1;
    return x < 0.4 ? 1 - Curves.easeIn.transform(x / 0.4) : Curves.easeOut.transform((x - 0.4) / 0.6);
  }

  /// Starts a tilt if it's time; returns the current tilt in radians.
  double tilt(double t, {double? followAt}) {
    if (followAt != null && followAt > tiltAt + tiltIn * 2 + tiltHold) {
      tiltAt = followAt;
    } else if (t >= nextTilt) {
      tiltAt = t;
      tiltHold = 1.2 + random.nextDouble() * 0.8;
      tiltSign = random.nextBool() ? 1 : -1;
      nextTilt = t + 7 + random.nextDouble() * 7;
    }
    final x = t - tiltAt;
    return tiltSign * 0.12 * _bump(x, 0, tiltIn, tiltIn + tiltHold, tiltIn * 2 + tiltHold);
  }
}

/// Everything the painter needs for one frame; repaints when it changes.
class _Frame extends ChangeNotifier {
  BirdPose a = BirdPose.neutral, b = BirdPose.neutral;
  double leanA = 0.04, leanB = -0.04;
  double hopA = 0, hopB = 0;
  double sway = 0;
  double heartRise = 0;
  double heartScale = 1;

  /// Progress (0…1) of each little celebration heart, or null if not shown.
  final hearts = <double?>[null, null, null];

  void changed() => notifyListeners();
}

class MascotPairState extends State<MascotPair> with TickerProviderStateMixin {
  late final math.Random _random = math.Random(identityHashCode(this));
  late final _a = _BirdClock(3.7, _random, firstBlink: 1.2 + _random.nextDouble() * 2, firstTilt: 3 + _random.nextDouble() * 4);
  late final _b = _BirdClock(4.3, _random, firstBlink: 2.4 + _random.nextDouble() * 2, firstTilt: 8 + _random.nextDouble() * 5);
  final _frame = _Frame();

  late final Ticker _ticker = createTicker(_tick);
  Duration _lastElapsed = Duration.zero;
  double _time = 0;
  double _leanPhase = 0, _heartPhase = 0, _pulsePhase = 0;

  // Mood blending.
  late final AnimationController _moodAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))
    ..addListener(_update);
  double _curiousFrom = 0, _thoughtfulFrom = 0;
  double _curious = 0, _thoughtful = 0;

  // One controller per reaction, so they can overlap without hard cuts.
  late final Map<MascotReaction, AnimationController> _reactions = {
    for (final (r, ms) in [(MascotReaction.glance, 1400), (MascotReaction.cheer, 1100), (MascotReaction.celebrate, 1800)])
      r: AnimationController(
        vsync: this,
        duration: Duration(milliseconds: ms),
      )..addListener(_update),
  };
  int _seenReactions = 0;
  bool _reduced = false;

  /// False while the birds are on a hidden tab; reactions wait for them.
  bool _visible = true;
  MascotReaction? _pending;

  /// Blinks so far, for tests.
  @visibleForTesting
  int get blinkCount => _a.blinks + _b.blinks;

  @override
  void initState() {
    super.initState();
    _curious = widget.mood == MascotMood.curious ? 1 : 0;
    _thoughtful = widget.mood == MascotMood.thoughtful ? 1 : 0;
    _seenReactions = widget.controller?.count ?? 0;
    widget.controller?.addListener(_onController);
    final first = widget.playOnMount;
    if (first != null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? react(first) : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _visible = TickerMode.valuesOf(context).enabled;
    final pending = _pending;
    if (_visible && pending != null) {
      _pending = null;
      // Let the tab finish fading in before reacting.
      Future.delayed(const Duration(milliseconds: 350), () => mounted ? react(pending) : null);
    }
    _sync();
  }

  @override
  void didUpdateWidget(MascotPair oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onController);
      _seenReactions = widget.controller?.count ?? 0;
      widget.controller?.addListener(_onController);
    }
    if (old.mood != widget.mood) {
      _curiousFrom = _curious;
      _thoughtfulFrom = _thoughtful;
      if (_reduced) {
        _moodAnim.value = 1;
      } else {
        _moodAnim.forward(from: 0);
      }
    }
    _sync();
  }

  void _sync() {
    final run = widget.animate && !_reduced;
    if (run && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
    _update();
  }

  void _onController() {
    final c = widget.controller!;
    if (c.count == _seenReactions) return;
    _seenReactions = c.count;
    final r = c.last;
    if (r != null) react(r);
  }

  /// Plays [reaction] now. Repeats while one is still mostly playing are
  /// ignored rather than cut off.
  void react(MascotReaction reaction) {
    if (!_visible) {
      // On a hidden tab: play it when the birds are seen again.
      _pending = reaction;
      return;
    }
    final anim = _reactions[reaction]!;
    if (anim.isAnimating && anim.value < 0.85) return;
    anim.forward(from: 0);
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastElapsed = elapsed;
    _time += dt;
    final slow = 1 + 0.25 * _thoughtful;
    _a.advance(_time, dt, slow);
    _b.advance(_time, dt, slow);
    _leanPhase += dt * 2 * math.pi / 6.5;
    _heartPhase += dt * 2 * math.pi / 5.5;
    _pulsePhase += dt * 2 * math.pi / 3.1;
    _update();
  }

  void _update() {
    if (!mounted) return;
    final idle = _ticker.isActive ? 1.0 : 0.0;
    final m = Curves.easeInOut.transform(_moodAnim.value);
    final target = widget.mood;
    _curious = _curiousFrom + ((target == MascotMood.curious ? 1 : 0) - _curiousFrom) * (_moodAnim.isDismissed ? 1 : m);
    _thoughtful = _thoughtfulFrom + ((target == MascotMood.thoughtful ? 1 : 0) - _thoughtfulFrom) * (_moodAnim.isDismissed ? 1 : m);
    final c = _curious, th = _thoughtful;
    final motion = _reduced ? 0.0 : 1.0;

    final glance = _reactions[MascotReaction.glance]!.value;
    final cheer = _reactions[MascotReaction.cheer]!.value;
    final party = _reactions[MascotReaction.celebrate]!.value;
    final glancing = _reactions[MascotReaction.glance]!.isAnimating;
    final cheering = _reactions[MascotReaction.cheer]!.isAnimating;
    final partying = _reactions[MascotReaction.celebrate]!.isAnimating;

    // Idle breathing, blinks and tilts, each bird on its own clock.
    final tiltA = idle * _a.tilt(_time);
    final tiltB = idle * _b.tilt(_time, followAt: tiltA.abs() > 0.02 && _random.nextDouble() < 0.004 ? _time + 0.3 : null);
    var breatheA = idle * math.sin(_a.phase), breatheB = idle * math.sin(_b.phase + 1.3);
    var hopA = 0.0, hopB = 0.0, wingA = 0.0, wingB = 0.0, joyA = 0.0, joyB = 0.0;
    var gazeA = Offset.zero, gazeB = Offset.zero;
    var headA = tiltA, headB = tiltB;
    var leanExtraA = 0.0, leanExtraB = 0.0;

    // Reaction curves: anticipation, action, follow-through.
    double hopCurve(double p) =>
        0.025 * _bump(p, 0, 0.08, 0.1, 0.18) - 0.07 * _bump(p, 0.15, 0.32, 0.34, 0.52) + 0.012 * _bump(p, 0.5, 0.56, 0.58, 0.7);
    double squashCurve(double p) =>
        -1.4 * _bump(p, 0, 0.08, 0.1, 0.17) + 1.2 * _bump(p, 0.17, 0.27, 0.3, 0.42) - 1.1 * _bump(p, 0.48, 0.54, 0.55, 0.68);
    if (cheering) {
      final pa = cheer, pb = (cheer - 0.07).clamp(0.0, 1.0);
      hopA += hopCurve(pa) * motion;
      hopB += hopCurve(pb) * motion;
      breatheA += squashCurve(pa) * motion;
      breatheB += squashCurve(pb) * motion;
      wingA += 0.55 * _bump(pa, 0.15, 0.27, 0.4, 0.58) * motion;
      wingB += 0.55 * _bump(pb, 0.15, 0.27, 0.4, 0.58) * motion;
      joyA = math.max(joyA, _bump(pa, 0.08, 0.2, 0.78, 1));
      joyB = math.max(joyB, _bump(pb, 0.08, 0.2, 0.78, 1));
    }
    if (partying) {
      final p = party, q = (party - 0.05).clamp(0.0, 1.0);
      double bounce(double x) =>
          0.03 * _bump(x, 0, 0.06, 0.08, 0.13) -
          0.1 * _bump(x, 0.12, 0.24, 0.25, 0.38) -
          0.05 * _bump(x, 0.4, 0.49, 0.5, 0.6) +
          0.01 * _bump(x, 0.6, 0.64, 0.65, 0.72);
      double squash(double x) =>
          -1.4 * _bump(x, 0, 0.06, 0.08, 0.12) + _bump(x, 0.12, 0.2, 0.22, 0.32) - 0.9 * _bump(x, 0.36, 0.4, 0.41, 0.46);
      double flap(double x) =>
          x < 0.12 || x > 0.66 ? 0 : 0.7 * math.sin((x - 0.12) / 0.54 * 4 * math.pi).abs() * _bump(x, 0.12, 0.18, 0.6, 0.66);
      hopA += bounce(p) * motion;
      hopB += bounce(q) * motion;
      breatheA += squash(p) * motion;
      breatheB += squash(q) * motion;
      wingA += flap(p) * motion;
      wingB += flap(q) * motion;
      joyA = math.max(joyA, _bump(p, 0.04, 0.14, 0.88, 1));
      joyB = math.max(joyB, _bump(q, 0.04, 0.14, 0.88, 1));
    }
    if (glancing) {
      // Anticipation (a little lift), then a lean and head turn down toward
      // the new entry; the partner follows a beat later.
      final ka = _bump(glance, 0.08, 0.24, 0.72, 0.94) * motion;
      final kb = _bump(glance, 0.2, 0.36, 0.78, 0.98) * motion;
      hopA -= 0.03 * _bump(glance, 0, 0.05, 0.06, 0.12) * motion;
      headA += 0.3 * ka;
      leanExtraA += 0.09 * ka;
      gazeA += const Offset(1, 1) * ka;
      headB += -0.18 * kb;
      leanExtraB += -0.04 * kb;
      gazeB += const Offset(-0.5, 1) * kb;
    }

    // Moods.
    headB += -0.2 * c;
    gazeB += Offset(-0.4, 0.15) * c;
    wingA += 0.3 * c;
    gazeA += Offset(0.6, 0.7) * c;
    headA += 0.05 * th;
    headB += -0.05 * th;
    gazeA += const Offset(-0.6, -0.8) * th;
    gazeB += const Offset(-0.6, -0.8) * th;

    final f = _frame;
    f.a = BirdPose(
      breathe: breatheA,
      headTilt: headA * motion,
      eyeOpen: idle * (_a.eyeOpen(_time) - 1) + 1,
      joy: joyA,
      gaze: gazeA * (1 - joyA),
      wingLift: wingA,
      thoughtful: th,
    );
    f.b = BirdPose(
      breathe: breatheB,
      headTilt: headB * motion,
      eyeOpen: idle * (_b.eyeOpen(_time) - 1) + 1,
      joy: joyB,
      gaze: gazeB * (1 - joyB),
      wingLift: wingB,
      thoughtful: th,
    );
    // Leaning in toward each other, a little more with each breath.
    f.leanA = 0.035 + idle * 0.012 * math.sin(_leanPhase) + 0.03 * c * motion + leanExtraA;
    f.leanB = -0.035 - idle * 0.012 * math.sin(_leanPhase + 0.8) + leanExtraB;
    f.hopA = hopA;
    f.hopB = hopB;
    f.sway = idle * math.sin(_leanPhase);
    // The heart drifts up and back on a slow sine and breathes on another.
    f.heartRise = idle * (0.5 + 0.5 * math.sin(_heartPhase));
    f.heartScale =
        1 +
        idle * 0.06 * math.sin(_pulsePhase) +
        (cheering ? 0.25 * _bump(cheer, 0.2, 0.34, 0.36, 0.62) * motion : 0) +
        (partying ? 0.35 * _bump(party, 0.1, 0.24, 0.42, 0.72) * motion : 0);
    for (var i = 0; i < 3; i++) {
      final start = 0.15 + i * 0.1;
      f.hearts[i] = partying && !_reduced && party >= start && party <= start + 0.55 ? (party - start) / 0.55 : null;
    }
    f.changed();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onController);
    _ticker.dispose();
    _moodAnim.dispose();
    for (final r in _reactions.values) {
      r.dispose();
    }
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Semantics(
      image: true,
      label: 'Pairnest birds',
      child: SizedBox(
        width: widget.width,
        height: widget.width * 0.8,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _PairPainter(
              frame: _frame,
              birdA: p.birdA,
              birdB: p.birdB,
              leafColor: p.primary,
              heart: widget.heart,
              leaves: widget.leaves,
              bubbles: widget.bubbles,
              branch: widget.branch,
              bubbleColor: p.surface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sunset bench scene used on the second onboarding page.
class BenchScene extends StatelessWidget {
  const BenchScene({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return CustomPaint(
      painter: _BenchPainter(birdA: p.birdA, birdB: p.birdB, foliage: p.primaryDeep),
      child: const SizedBox.expand(),
    );
  }
}

/// The pair in a round avatar badge (dashboard header).
class MascotBadge extends StatelessWidget {
  const MascotBadge({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.soft,
        border: Border.all(color: p.surface, width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: OverflowBox(
        maxWidth: size * 1.35,
        maxHeight: size * 1.35,
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.18),
          child: MascotPair(width: size * 1.1, leaves: false),
        ),
      ),
    );
  }
}

/// Two crossed leaf sprigs, the decoration in the mockup's corners.
class LeafSprigs extends StatelessWidget {
  const LeafSprigs({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.pn.primary;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SprigsPainter(color)),
    );
  }
}

class _SprigsPainter extends CustomPainter {
  _SprigsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    drawSprig(canvas, Offset(size.width * 0.45, size.height), size.height * 0.95, color, sway: 0.35);
    drawSprig(canvas, Offset(size.width * 0.55, size.height), size.height * 0.7, color.withValues(alpha: 0.6), sway: 0.9);
  }

  @override
  bool shouldRepaint(_SprigsPainter old) => old.color != color;
}

/// A small single bird, e.g. for headers.
class MascotBird extends StatelessWidget {
  const MascotBird({super.key, this.size = 40, this.color, this.faceRight = true});

  final double size;
  final Color? color;
  final bool faceRight;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pn.birdA;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SingleBirdPainter(c, faceRight)),
    );
  }
}

Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;
Color _darken(Color c, double t) => Color.lerp(c, Colors.black, t)!;

/// One logo-style bird: round body, cream face mask and belly, eyes, yellow
/// beak and feet. [faceRight] turns the face toward the partner; [lashes]
/// adds blush and eyelashes like the lighter bird in the logo. [pose] moves
/// its parts for animation; the default stands still with eyes open.
void drawBird(
  Canvas canvas,
  Offset c,
  double r,
  Color color, {
  bool faceRight = true,
  bool lashes = false,
  BirdPose pose = BirdPose.neutral,
}) {
  final dir = faceRight ? 1.0 : -1.0;
  final ink = _darken(color, 0.55);
  final face = c + Offset(dir * r * 0.14, 0);
  final head = c + Offset(0, -r * 0.3);

  // Ground shadow stays on the ground.
  canvas.drawOval(
    Rect.fromCenter(center: c + Offset(0, r * 1.08), width: r * 1.7, height: r * 0.22),
    Paint()..color = Colors.black.withValues(alpha: 0.08),
  );

  // Breathing: a gentle squash and stretch with the feet pinned.
  canvas.save();
  final feet = c + Offset(0, r * 1.04);
  canvas.translate(feet.dx, feet.dy);
  canvas.scale(1 - 0.012 * pose.breathe, 1 + 0.025 * pose.breathe);
  canvas.translate(-feet.dx, -feet.dy);

  void tiltHead() {
    canvas.translate(head.dx, head.dy);
    canvas.rotate(pose.headTilt);
    canvas.translate(-head.dx, -head.dy);
  }

  // Head feathers (behind the body; they tilt with the head).
  canvas.save();
  tiltHead();
  final tuft = Paint()..color = _darken(color, 0.12);
  for (final (dx, angle, len) in [(-0.22, -0.55, 0.36), (0.0, -0.1, 0.42), (0.2, 0.35, 0.32)]) {
    canvas.save();
    canvas.translate(c.dx + (dx + dir * 0.06) * r, c.dy - r * 0.98);
    canvas.rotate(angle);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -r * len * 0.45), width: r * 0.2, height: r * len), tuft);
    canvas.restore();
  }
  canvas.restore();

  // Tail feathers behind the body.
  canvas.save();
  canvas.translate(c.dx - dir * r * 0.92, c.dy + r * 0.45);
  canvas.rotate(-dir * 0.9);
  canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.32, height: r * 0.62), Paint()..color = _darken(color, 0.2));
  canvas.restore();

  // Body.
  final body = Rect.fromCenter(center: c, width: r * 2, height: r * 2.15);
  canvas.drawOval(
    body,
    Paint()
      ..shader = RadialGradient(
        center: Alignment(0.2 * dir, -0.55),
        radius: 1.0,
        colors: [_lighten(color, 0.22), color, _darken(color, 0.1)],
        stops: const [0, 0.6, 1],
      ).createShader(body),
  );

  // Cream belly, then the face mask's two lobes (these tilt with the head).
  final cream = Paint()..color = _cream;
  canvas.drawOval(Rect.fromCenter(center: face + Offset(0, r * 0.32), width: r * 1.22, height: r * 1.25), cream);
  canvas.save();
  tiltHead();
  canvas.drawCircle(face + Offset(-r * 0.33, -r * 0.3), r * 0.43, cream);
  canvas.drawCircle(face + Offset(r * 0.33, -r * 0.3), r * 0.43, cream);
  canvas.restore();

  // Wing hugging the side; it lifts outward from the shoulder.
  canvas.save();
  canvas.translate(c.dx - dir * r * 0.478, c.dy - r * 0.178);
  canvas.rotate(dir * (0.3 - 1.25 * pose.wingLift));
  canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.48), width: r * 0.62, height: r * 1.05), Paint()..color = _darken(color, 0.08));
  canvas.restore();

  // Feet.
  final foot = Paint()..color = _beakYellow;
  for (final dx in [-0.32, 0.32]) {
    canvas.drawOval(Rect.fromCenter(center: c + Offset(dx * r, r * 1.04), width: r * 0.42, height: r * 0.2), foot);
  }

  canvas.save();
  tiltHead();
  _eyes(canvas, face, r, ink, dir, lashes, pose);

  // Blush.
  final blush = Paint()..color = const Color(0xFFF4A6A0).withValues(alpha: lashes ? 0.7 : 0.35);
  for (final side in [-1.0, 1.0]) {
    canvas.drawOval(Rect.fromCenter(center: face + Offset(side * r * 0.5, -r * 0.04), width: r * 0.24, height: r * 0.15), blush);
  }

  // Beak; the little smile flattens when thoughtful.
  final beak = face + Offset(0, -r * 0.1);
  canvas.drawPath(
    Path()
      ..moveTo(beak.dx - r * 0.16, beak.dy - r * 0.04)
      ..quadraticBezierTo(beak.dx, beak.dy - r * 0.14, beak.dx + r * 0.16, beak.dy - r * 0.04)
      ..quadraticBezierTo(beak.dx + dir * r * 0.04, beak.dy + r * 0.16, beak.dx - r * 0.16, beak.dy - r * 0.04)
      ..close(),
    Paint()..color = _beakYellow,
  );
  canvas.drawArc(
    Rect.fromCenter(center: beak + Offset(0, r * 0.03), width: r * 0.16, height: r * 0.1 * (1 - 0.8 * pose.thoughtful)),
    0.2,
    math.pi - 0.4,
    false,
    Paint()
      ..color = _darken(_beakYellow, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03,
  );
  canvas.restore();
  canvas.restore();
}

/// Open eyes that blink and look around, cross-fading to the logo's happy
/// "^ ^" with [BirdPose.joy]; thoughtful adds softly raised brows.
void _eyes(Canvas canvas, Offset face, double r, Color ink, double dir, bool lashes, BirdPose pose) {
  final joy = pose.joy.clamp(0.0, 1.0);
  final open = pose.eyeOpen.clamp(0.0, 1.0);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.075
    ..strokeCap = StrokeCap.round;
  for (final side in [-1.0, 1.0]) {
    final e = face + Offset(side * r * 0.36, -r * 0.3);
    if (joy < 1) {
      final a = 1 - joy;
      final look = e + Offset(pose.gaze.dx.clamp(-1.0, 1.0) * r * 0.08, pose.gaze.dy.clamp(-1.0, 1.0) * r * 0.07);
      if (open > 0.18) {
        final h = r * 0.22 * open;
        canvas.drawOval(Rect.fromCenter(center: look, width: r * 0.17, height: h), Paint()..color = ink.withValues(alpha: a));
        canvas.drawCircle(look + Offset(-r * 0.03, -h * 0.22), r * 0.032 * open, Paint()..color = Colors.white.withValues(alpha: 0.9 * a));
      } else {
        // Shut mid-blink: a soft line.
        canvas.drawLine(look - Offset(r * 0.08, 0), look + Offset(r * 0.08, 0), stroke..color = ink.withValues(alpha: a));
      }
      if (lashes && side == dir) {
        final top = look + Offset(side * r * 0.07, -r * 0.08 * math.max(open, 0.3));
        canvas.drawLine(top, top + Offset(side * r * 0.08, -r * 0.05), (stroke..strokeWidth = r * 0.045)..color = ink.withValues(alpha: a));
        stroke.strokeWidth = r * 0.075;
      }
      if (pose.thoughtful > 0) {
        // Softly raised, arched brows: considering, never stern or worried.
        final brow = e + Offset(0, -r * 0.21);
        canvas.drawArc(
          Rect.fromCenter(center: brow + Offset(0, r * 0.03), width: r * 0.16, height: r * 0.08),
          math.pi + 0.35,
          math.pi - 0.7,
          false,
          (stroke..strokeWidth = r * 0.035)..color = ink.withValues(alpha: 0.7 * a * pose.thoughtful),
        );
        stroke.strokeWidth = r * 0.075;
      }
    }
    if (joy > 0) {
      stroke.color = ink.withValues(alpha: joy);
      canvas.drawArc(Rect.fromCenter(center: e, width: r * 0.3, height: r * 0.24), math.pi + 0.25, math.pi - 0.5, false, stroke);
      if (lashes && side == dir) {
        canvas.drawLine(e + Offset(side * r * 0.14, -r * 0.02), e + Offset(side * r * 0.22, -r * 0.08), stroke);
      }
    }
  }
}

void drawHeart(Canvas canvas, Offset c, double s, [Color color = brandYellow]) {
  final path = Path()
    ..moveTo(c.dx, c.dy + s * 0.55)
    ..cubicTo(c.dx - s * 1.1, c.dy - s * 0.1, c.dx - s * 0.55, c.dy - s * 0.95, c.dx, c.dy - s * 0.35)
    ..cubicTo(c.dx + s * 0.55, c.dy - s * 0.95, c.dx + s * 1.1, c.dy - s * 0.1, c.dx, c.dy + s * 0.55)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

void drawSprig(Canvas canvas, Offset base, double h, Color color, {bool leanRight = true, double sway = 0}) {
  final dir = leanRight ? 1.0 : -1.0;
  canvas.save();
  canvas.translate(base.dx, base.dy);
  canvas.rotate(sway);
  final stem = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = h * 0.03
    ..strokeCap = StrokeCap.round;
  final tip = Offset(dir * h * 0.25, -h);
  canvas.drawPath(Path()..quadraticBezierTo(-dir * h * 0.05, -h * 0.6, tip.dx, tip.dy), stem);
  final leaf = Paint()..color = color.withValues(alpha: 0.85);
  for (var i = 1; i <= 4; i++) {
    final p = Offset.lerp(Offset.zero, tip, i / 5)!;
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(side * 0.9 + dir * 0.25);
      canvas.drawOval(Rect.fromCenter(center: Offset(0, -h * 0.07), width: h * 0.08, height: h * 0.16), leaf);
      canvas.restore();
    }
  }
  canvas.restore();
}

class _PairPainter extends CustomPainter {
  _PairPainter({
    required this.frame,
    required this.birdA,
    required this.birdB,
    required this.leafColor,
    required this.heart,
    required this.leaves,
    required this.bubbles,
    required this.bubbleColor,
    this.branch = false,
  }) : super(repaint: frame);

  final _Frame frame;
  final Color birdA, birdB, leafColor, bubbleColor;
  final bool heart, leaves, bubbles, branch;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final f = frame;
    final r = w * 0.2;

    if (branch) _branch(canvas, w, h, f.sway);
    if (leaves && !branch) {
      drawSprig(canvas, Offset(w * 0.08, h * 0.95), h * 0.5, leafColor, leanRight: false, sway: -0.04 * f.sway);
      drawSprig(canvas, Offset(w * 0.92, h * 0.95), h * 0.5, leafColor, sway: 0.04 * f.sway);
    }

    // Each bird leans in toward the other from its feet and can hop.
    void bird(
      Offset c,
      double radius,
      Color color,
      BirdPose pose,
      double lean,
      double hop, {
      required bool faceRight,
      bool lashes = false,
    }) {
      final feet = c + Offset(0, radius * 1.1);
      canvas.save();
      canvas.translate(feet.dx, feet.dy + hop * radius);
      canvas.rotate(lean);
      canvas.translate(-feet.dx, -feet.dy);
      drawBird(canvas, c, radius, color, faceRight: faceRight, lashes: lashes, pose: pose);
      canvas.restore();
    }

    final Offset centerA, centerB;
    final double radiusA, radiusB;
    if (branch) {
      final br = r * 0.82;
      (centerA, radiusA) = (Offset(w * 0.4, h * 0.73 - br * 1.1), br);
      (centerB, radiusB) = (Offset(w * 0.62, h * 0.7 - br * 1.0), br * 0.9);
    } else {
      (centerA, radiusA) = (Offset(w * 0.38, h * 0.6), r);
      (centerB, radiusB) = (Offset(w * 0.63, h * 0.63), r * 0.9);
    }
    bird(centerA, radiusA, birdA, f.a, f.leanA, f.hopA, faceRight: true);
    bird(centerB, radiusB, birdB, f.b, f.leanB, f.hopB, faceRight: false, lashes: true);

    if (heart) {
      drawHeart(canvas, Offset(w * 0.51, h * 0.19 - f.heartRise * h * 0.03), w * 0.065 * f.heartScale);
    }
    // Little hearts rising from between the birds when they celebrate.
    for (final (i, progress) in f.hearts.indexed) {
      if (progress == null) continue;
      final x = w * (0.44 + 0.08 * i) + math.sin(progress * math.pi * 2 + i) * w * 0.02;
      final y = h * (0.42 - 0.38 * Curves.easeOut.transform(progress));
      final alpha = progress < 0.2 ? progress / 0.2 : 1 - (progress - 0.2) / 0.8;
      drawHeart(canvas, Offset(x, y), w * (0.03 + 0.008 * i), brandYellow.withValues(alpha: alpha.clamp(0.0, 1.0)));
    }
    if (bubbles) {
      final drift = f.sway * h * 0.015;
      _bubble(canvas, Offset(w * 0.28, h * 0.12 + drift), w * 0.15);
      _bubble(canvas, Offset(w * 0.72, h * 0.1 - drift), w * 0.13);
    }
  }

  /// A gently swaying branch with leaves at both ends.
  void _branch(Canvas canvas, double w, double h, double sway) {
    final wood = Paint()
      ..color = const Color(0xFF8A6A55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.035
      ..strokeCap = StrokeCap.round;
    final y = sway * h * 0.006;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.04, h * 0.84 + y)
        ..quadraticBezierTo(w * 0.5, h * 0.66 + y, w * 0.98, h * 0.7 + y),
      wood,
    );
    drawSprig(canvas, Offset(w * 0.86, h * 0.71 + y), h * 0.42, leafColor, sway: 0.5 + 0.05 * sway);
    drawSprig(canvas, Offset(w * 0.14, h * 0.8 + y), h * 0.34, leafColor, leanRight: false, sway: -0.6 - 0.05 * sway);
  }

  void _bubble(Canvas canvas, Offset c, double width) {
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: width, height: width * 0.62), Radius.circular(width * 0.3));
    canvas.drawRRect(rect.shift(const Offset(0, 2)), Paint()..color = Colors.black.withValues(alpha: 0.06));
    canvas.drawRRect(rect, Paint()..color = bubbleColor);
    final dot = Paint()..color = brandYellow;
    for (final dx in [-1, 0, 1]) {
      canvas.drawCircle(c + Offset(dx * width * 0.2, 0), width * 0.055, dot);
    }
  }

  @override
  bool shouldRepaint(_PairPainter old) =>
      old.frame != frame ||
      old.birdA != birdA ||
      old.birdB != birdB ||
      old.leafColor != leafColor ||
      old.bubbleColor != bubbleColor ||
      old.heart != heart ||
      old.leaves != leaves ||
      old.bubbles != bubbles ||
      old.branch != branch;
}

class _SingleBirdPainter extends CustomPainter {
  _SingleBirdPainter(this.color, this.faceRight);

  final Color color;
  final bool faceRight;

  @override
  void paint(Canvas canvas, Size size) {
    drawBird(canvas, Offset(size.width / 2, size.height * 0.55), size.width * 0.36, color, faceRight: faceRight);
  }

  @override
  bool shouldRepaint(_SingleBirdPainter old) => old.color != color || old.faceRight != faceRight;
}

class _BenchPainter extends CustomPainter {
  _BenchPainter({required this.birdA, required this.birdB, required this.foliage});

  final Color birdA, birdB, foliage;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final full = Offset.zero & size;

    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9C6D3), Color(0xFFF6CDB2), Color(0xFFFBE3CC)],
        ).createShader(full),
    );
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.13, Paint()..color = const Color(0xFFFFEBD2));

    // Far mountains and water.
    final far = Path()..moveTo(0, h * 0.55);
    for (var i = 0; i <= 8; i++) {
      far.lineTo(w * i / 8, h * (0.5 + 0.08 * math.sin(i * 1.7)));
    }
    far
      ..lineTo(w, h * 0.62)
      ..lineTo(0, h * 0.62)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFFC7A9C2));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.6, w, h * 0.4), Paint()..color = const Color(0xFFE8C9BE));

    // Foreground foliage at the edges.
    final leaf = Paint()..color = foliage.withValues(alpha: 0.9);
    for (final c in [
      Offset(-w * 0.02, h * 0.3),
      Offset(w * 0.08, h * 0.18),
      Offset(w * 0.02, h * 0.55),
      Offset(w * 1.02, h * 0.28),
      Offset(w * 0.93, h * 0.15),
      Offset(w * 0.98, h * 0.5),
    ]) {
      canvas.drawCircle(c, w * 0.11, leaf);
    }

    // Bench.
    final wood = Paint()..color = const Color(0xFF6B4A3A);
    final seatY = h * 0.8;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.15, seatY, w * 0.7, h * 0.035), const Radius.circular(4)), wood);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.15, seatY - h * 0.09, w * 0.7, h * 0.03), const Radius.circular(4)), wood);
    for (final x in [0.2, 0.78]) {
      canvas.drawRect(Rect.fromLTWH(w * x, seatY, w * 0.025, h * 0.2), wood);
    }

    final r = w * 0.11;
    drawBird(canvas, Offset(w * 0.42, seatY - r * 1.05), r, birdA);
    drawBird(canvas, Offset(w * 0.6, seatY - r * 0.98), r * 0.92, birdB, faceRight: false, lashes: true);
    drawHeart(canvas, Offset(w * 0.51, seatY - r * 2.9), w * 0.035);
  }

  @override
  bool shouldRepaint(_BenchPainter old) => old.birdA != birdA || old.birdB != birdB || old.foliage != foliage;
}
