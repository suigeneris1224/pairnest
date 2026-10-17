import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/core/mascot/mascot.dart';
import 'package:pairnest/core/theme/app_theme.dart';
import 'package:pairnest/core/theme/palettes.dart';

Future<void> _pump(WidgetTester tester, Widget child, {bool reducedMotion = false}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(paletteById('sage'), googleFonts: false),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

MascotPairState _state(WidgetTester tester) => tester.state<MascotPairState>(find.byType(MascotPair));

void main() {
  testWidgets('idle birds blink on their own, at natural intervals', (tester) async {
    await _pump(tester, const MascotPair(animate: true));
    expect(_state(tester).blinkCount, 0);

    // Several seconds of idling: both birds blink, but not every frame.
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final blinks = _state(tester).blinkCount;
    expect(blinks, greaterThanOrEqualTo(2));
    expect(blinks, lessThan(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps the birds still: no frames scheduled', (tester) async {
    await _pump(tester, const MascotPair(animate: true, branch: true), reducedMotion: true);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_state(tester).blinkCount, 0);
  });

  testWidgets('reactions play and finish, even when the idle loop is off', (tester) async {
    final controller = MascotController();
    addTearDown(controller.dispose);
    await _pump(tester, MascotPair(controller: controller));

    for (final reaction in MascotReaction.values) {
      controller.react(reaction);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue, reason: '$reaction animates');
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
    }
    // All done: nothing left ticking.
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moods blend in, and disposing mid-reaction is safe', (tester) async {
    final controller = MascotController();
    addTearDown(controller.dispose);
    await _pump(tester, MascotPair(animate: true, controller: controller));
    await tester.pump(const Duration(milliseconds: 300));

    for (final mood in [MascotMood.curious, MascotMood.thoughtful, MascotMood.idle]) {
      await _pump(tester, MascotPair(animate: true, controller: controller, mood: mood));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));
    }
    controller.react(MascotReaction.celebrate);
    await tester.pump(const Duration(milliseconds: 500));
    await _pump(tester, const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a celebration can play as soon as the birds appear', (tester) async {
    await _pump(tester, const MascotPair(playOnMount: MascotReaction.celebrate));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('single birds and the badge still draw', (tester) async {
    await _pump(tester, const Row(mainAxisSize: MainAxisSize.min, children: [MascotBird(size: 40), MascotBadge(size: 56)]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reaction on a hidden tab waits and plays when the birds are seen', (tester) async {
    final controller = MascotController();
    addTearDown(controller.dispose);
    Widget birds({required bool visible}) => TickerMode(
      enabled: visible,
      child: MascotPair(controller: controller),
    );

    await _pump(tester, birds(visible: false));
    controller.react(MascotReaction.glance);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing plays while hidden');

    await _pump(tester, birds(visible: true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.hasScheduledFrame, isTrue, reason: 'the glance plays once visible');
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
