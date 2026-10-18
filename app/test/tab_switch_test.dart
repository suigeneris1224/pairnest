import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/app.dart';
import 'package:pairnest/data/mock_repository.dart';
import 'package:pairnest/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Opacity of the tab layer that contains [text] (1 = on screen, 0 = hidden).
double _tabOpacity(WidgetTester tester, String text) {
  final layer = find.ancestor(of: find.text(text).first, matching: find.byType(AnimatedOpacity)).last;
  return (tester.renderObject(layer) as RenderAnimatedOpacity).opacity.value;
}

void main() {
  // Regression: leaving the Us tab (especially from one of its sub-pages) left
  // it frozen on top of the other tabs, so the app looked stuck.
  testWidgets('switching away from Us hides it, including its sub-pages', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true, 'theme_chosen': true});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          useGoogleFontsProvider.overrideWithValue(false),
          repositoryProvider.overrideWithValue(MockRepository(latency: Duration.zero)),
        ],
        child: const PairnestApp(),
      ),
    );
    await _settle(tester);
    final c = ProviderScope.containerOf(tester.element(find.byType(PairnestApp)));
    final login = c.read(sessionProvider.notifier).recover(MockRepository.demoKey);
    await _settle(tester);
    await login;

    Future<void> tap(Finder f) async {
      await tester.tap(f);
      await _settle(tester);
    }

    await tap(find.text('Us').last);
    expect(_tabOpacity(tester, 'Same team. Different strengths. One journey.'), 1);

    // Open a sub-page from Us, then switch tabs.
    await tap(find.text('Money Talks').last);
    expect(find.text('Weekly Conversation'), findsOneWidget);
    await tap(find.text('Home').last);
    expect(_tabOpacity(tester, 'Weekly Conversation'), 0);
    expect(_tabOpacity(tester, 'Left to spend'), 1);

    await tap(find.text('Goals').last);
    expect(_tabOpacity(tester, 'Weekly Conversation'), 0);
    expect(_tabOpacity(tester, 'Our Goals'), 1);

    // Back to Us: still on its sub-page; back arrow returns to the Us menu.
    await tap(find.text('Us').last);
    expect(_tabOpacity(tester, 'Weekly Conversation'), 1);
    await tap(find.byTooltip('Back').last);
    await tap(find.text('Activity').last);
    expect(_tabOpacity(tester, 'Same team. Different strengths. One journey.'), 0);
    expect(_tabOpacity(tester, 'Money in'), 1);
  });
}
