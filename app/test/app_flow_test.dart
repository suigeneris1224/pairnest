import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/app.dart';
import 'package:pairnest/core/format.dart';
import 'package:pairnest/core/widgets/member_avatar.dart';
import 'package:pairnest/core/mascot/mascot.dart';
import 'package:pairnest/core/theme/palettes.dart';
import 'package:pairnest/data/mock_repository.dart';
import 'package:pairnest/data/models.dart';
import 'package:pairnest/data/payday_schedule.dart';
import 'package:pairnest/data/providers.dart';
import 'package:pairnest/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  Map<String, Object> prefs, {
  bool reducedMotion = false,
  MockRepository? repo,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  if (reducedMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final instance = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(instance),
        useGoogleFontsProvider.overrideWithValue(false),
        repositoryProvider.overrideWithValue(repo ?? MockRepository(latency: Duration.zero)),
        ...overrides,
      ],
      child: const PairnestApp(),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(PairnestApp)));
}

Future<ProviderContainer> _signedIn(WidgetTester tester, {MockRepository? repo, List<Override> overrides = const []}) async {
  final container = await _pumpApp(tester, {'onboarded': true, 'theme_chosen': true}, repo: repo, overrides: overrides);
  // Timers only fire while the fake clock is pumped, so pump before awaiting.
  final login = container.read(sessionProvider.notifier).recover(MockRepository.demoKey);
  await _settle(tester);
  await login;
  return container;
}

/// pumpAndSettle never settles while a spinner is animating.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('welcome → explore the demo nest → home dashboard', (tester) async {
    await _pumpApp(tester, {});

    expect(find.text('Better\nMoney, Happier\nTogether.'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    await tester.tap(find.text('Explore the demo nest'));
    await _settle(tester);

    expect(find.text('Make it yours'), findsOneWidget);
    await tester.tap(find.text('Lavender'));
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(find.text('Alex & Sam'), findsOneWidget);
    expect(find.text('Shared Balance'), findsOneWidget);
    // Balance = ₱32,000 budget − ₱17,780 seeded spending.
    expect(find.text('₱14,220'), findsOneWidget);
    expect(find.text("This Month's Spending"), findsOneWidget);
  });

  testWidgets('choosing a palette re-themes the app', (tester) async {
    final container = await _pumpApp(tester, {'onboarded': true, 'theme_chosen': true});
    expect(container.read(themeProvider).id, 'sage');

    final select = container.read(themeProvider.notifier).select('midnight');
    await _settle(tester);
    await select;

    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.brightness, Brightness.dark);
    expect(theme.extension<PairnestPalette>()!.id, 'midnight');
  });

  testWidgets('bottom navigation reaches every tab', (tester) async {
    final container = await _pumpApp(tester, {'onboarded': true, 'theme_chosen': true});
    // Timers only fire while the fake clock is pumped, so pump before awaiting.
    final login = container.read(sessionProvider.notifier).recover(MockRepository.demoKey);
    await _settle(tester);
    await login;

    for (final (tab, title) in [('Activity', 'Money in'), ('Goals', 'Japan Trip'), ('Feelings', 'Our Feelings'), ('Us', 'Money Talks')]) {
      await tester.tap(find.text(tab).last);
      await _settle(tester);
      expect(find.text(title), findsWidgets, reason: tab);
    }
  });

  testWidgets('every sub-screen renders without layout errors', (tester) async {
    final container = await _pumpApp(tester, {'onboarded': true, 'theme_chosen': true});
    final login = container.read(sessionProvider.notifier).recover(MockRepository.demoKey);
    await _settle(tester);
    await login;

    final router = container.read(routerProvider);
    for (final (route, title) in [
      ('/home/budgets', 'Budgets'),
      ('/home/settle', 'Settle Up'),
      ('/add', 'Add Expense'),
      ('/add?type=income', 'Add Income'),
      ('/feelings/check-in', 'How are you feeling today?'),
      ('/us/talks', 'Weekly Conversation'),
      ('/us/planner', 'Date & Life Planner'),
      ('/us/personalize', 'Choose your theme'),
    ]) {
      router.go(route);
      await _settle(tester);
      expect(find.text(title), findsWidgets, reason: route);
    }

    // Tabs inside sub-screens.
    router.go('/us/planner');
    await _settle(tester);
    await tester.tap(find.text('Calendar'));
    await _settle(tester);
    router.go('/feelings');
    await _settle(tester);
    for (final tab in ['Both', 'Trends']) {
      await tester.tap(find.text(tab));
      await _settle(tester);
    }
    router.go('/us/personalize');
    await _settle(tester);
    await tester.tap(find.text('Settings'));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Remove this phone'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Remove this phone'), findsOneWidget);
  });

  testWidgets('reduced motion shows final values without waiting for animations', (tester) async {
    final container = await _pumpApp(tester, {'onboarded': true, 'theme_chosen': true}, reducedMotion: true);
    final login = container.read(sessionProvider.notifier).recover(MockRepository.demoKey);
    await _settle(tester);
    await login;

    // A couple of frames is enough: count-ups, fills and entrances are instant.
    container.read(routerProvider).go('/home/budgets');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('₱32,000'), findsWidgets);
  });

  testWidgets('eye toggle hides and reveals the balance', (tester) async {
    final container = await _pumpApp(tester, {'onboarded': true, 'theme_chosen': true});
    final login = container.read(sessionProvider.notifier).recover(MockRepository.demoKey);
    await _settle(tester);
    await login;

    expect(find.text('₱14,220'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide amounts'));
    await _settle(tester);
    expect(find.text('₱14,220'), findsNothing);
    expect(find.text('₱ ••••••'), findsOneWidget);
    expect(container.read(hideAmountsProvider), isTrue);

    await tester.tap(find.byTooltip('Show amounts'));
    await _settle(tester);
    expect(find.text('₱14,220'), findsOneWidget);
  });

  testWidgets('bell shows the partner feed and clears the dot', (tester) async {
    final container = await _pumpApp(tester, {'onboarded': true, 'theme_chosen': true});
    final login = container.read(sessionProvider.notifier).recover(MockRepository.demoKey);
    await _settle(tester);
    await login;

    expect(container.read(hasUnseenFeedProvider), isTrue);
    await tester.tap(find.byTooltip('Notifications'));
    await _settle(tester);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Sam saved toward Japan Trip'), findsOneWidget);
    expect(container.read(hasUnseenFeedProvider), isFalse);
  });

  testWidgets('a brand-new nest shows friendly empty states', (tester) async {
    final container = await _signedIn(tester, repo: MockRepository(latency: Duration.zero, seed: false));
    final router = container.read(routerProvider);

    await tester.scrollUntilVisible(find.textContaining('Nothing coming up'), 300, scrollable: find.byType(Scrollable).first);
    for (final (route, text) in [
      ('/activity', 'No transactions this month'),
      ('/goals', 'Dream something together'),
      ('/feelings', 'How are you feeling?'),
      ('/us/planner', 'Plan your next date'),
      ('/home/budgets', 'No budget for this month yet'),
    ]) {
      router.go(route);
      await _settle(tester);
      expect(find.text(text), findsOneWidget, reason: route);
    }
    expect(find.textContaining('Add rent, subscriptions'), findsOneWidget);
  });

  testWidgets('tapping a transaction edits it in place', (tester) async {
    final container = await _signedIn(tester);
    container.read(routerProvider).go('/activity');
    await _settle(tester);

    await tester.tap(find.text('Groceries'));
    await _settle(tester);
    expect(find.text('Edit Expense'), findsOneWidget);
    expect(find.widgetWithText(TextField, '1250'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '1250'), '1300');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);
    expect(find.text('Edit Expense'), findsNothing);
    expect(find.text('- ₱1,300'), findsOneWidget);
    expect(find.text('- ₱1,250'), findsNothing);
  });

  testWidgets('swipe deletes a transaction and Undo brings it back', (tester) async {
    final container = await _signedIn(tester);
    container.read(routerProvider).go('/activity');
    await _settle(tester);

    await tester.drag(find.text('Groceries'), const Offset(-600, 0));
    await _settle(tester);
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('"Groceries" deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('a due bill on Home can be marked paid', (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    await _signedIn(tester, repo: repo);
    // Mock futures only resolve while the fake clock is pumped.
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    final rent = (await resolve(repo.bills())).firstWhere((b) => b.title == 'Rent');

    await tester.ensureVisible(find.text('Rent'));
    await _settle(tester);
    expect(find.text('Due in 3 days'), findsOneWidget);
    await tester.tap(find.text('Rent'));
    await _settle(tester);
    expect(find.text('Mark Rent as paid?'), findsOneWidget);

    await tester.tap(find.text('Paid ₱15,000'));
    await _settle(tester);
    expect(find.textContaining('Rent paid'), findsOneWidget);

    final paid = (await resolve(repo.bills())).firstWhere((b) => b.id == rent.id);
    expect(paid.nextDueOn.month, (rent.nextDueOn.month % 12) + 1);
    final txns = await resolve(repo.transactions(month: DateTime.now()));
    expect(txns.where((t) => t.title == 'Rent' && t.amount == 15000), hasLength(1));
  });

  testWidgets('settling up from the Home nudge evens the balance, and Undo restores it', (tester) async {
    await _signedIn(tester);

    expect(find.text('Sam owes you ₱415'), findsOneWidget);
    await tester.tap(find.text('Sam owes you ₱415'));
    await _settle(tester);
    expect(find.text('Sam owes you'), findsOneWidget);
    expect(find.text('₱415'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Settle up'));
    await _settle(tester);
    await tester.tap(find.text('Record ₱415'));
    await _settle(tester);
    expect(find.text("You're all even"), findsOneWidget);
    expect(find.text('Sam paid you'), findsOneWidget);
    expect(find.text('Settled up · ₱415'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(find.text('₱415'), findsOneWidget);
    expect(find.text('Sam paid you'), findsNothing);
  });

  testWidgets('an expense paid by the partner moves the balance by half', (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final container = await _signedIn(tester, repo: repo);
    container.read(routerProvider).push('/add');
    await _settle(tester);

    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.ensureVisible(find.text('Paid by'));
    await _settle(tester);
    await tester.tap(find.text('Sam'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);

    // Sam's split total goes 5,400 → 6,400 against Alex's 6,230.
    final balance = repo.balance();
    await _settle(tester);
    final owes = (await balance).owes!;
    expect([owes.from.name, owes.amount], ['Alex', 85]);
    expect(find.text('You owe Sam ₱85'), findsOneWidget);
  });

  testWidgets('settle up waits for the partner to join', (tester) async {
    final repo = MockRepository(latency: Duration.zero, seed: false);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    final container = await _pumpApp(tester, {'onboarded': true, 'theme_chosen': true}, repo: repo);
    final session = container.read(sessionProvider.notifier);
    await resolve(session.start('Alex', const OnboardingProfile()));
    container.read(pendingRecoveryKeyProvider.notifier).saved();
    await resolve(session.createNest());

    container.read(routerProvider).go('/home/settle');
    await _settle(tester);
    expect(find.text('Invite your partner to start splitting'), findsOneWidget);
  });

  testWidgets('Home is a Pairnest wallet card, and Transfer saves without spending', (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final container = await _signedIn(tester, repo: repo);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    expect(find.text('ALEX & SAM'), findsOneWidget);
    expect(find.text('Our Card'), findsOneWidget);
    expect(find.text('pairnest'), findsNothing);
    expect(find.text('Shared Balance'), findsOneWidget);
    expect(find.text('₱14,220'), findsWidgets);
    final japanBefore = (await resolve(repo.goals())).firstWhere((g) => g.name == 'Japan Trip').saved;

    await tester.tap(find.text('Transfer'));
    await _settle(tester);
    expect(find.text('Transfer to a goal'), findsOneWidget);
    await tester.tap(find.text('Japan Trip').last);
    await tester.tap(find.widgetWithText(ChoiceChip, '₱1,000'));
    await _settle(tester);
    await tester.tap(find.text('Transfer ₱1,000 to Japan Trip'));
    await _settle(tester);

    expect(find.text('₱1,000 moved to Japan Trip'), findsOneWidget);
    expect(find.text('₱14,220'), findsWidgets, reason: 'savings are not spending');
    expect(find.text('₱1,000 saved toward goals this month'), findsOneWidget);
    expect((await resolve(repo.goals())).firstWhere((g) => g.name == 'Japan Trip').saved, japanBefore + 1000);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(find.textContaining('saved toward goals'), findsNothing);
    expect((await resolve(repo.goals())).firstWhere((g) => g.name == 'Japan Trip').saved, japanBefore);

    // Transfer again, then delete it from Activity.
    await resolve(repo.contribute(1, 2500));
    container.read(routerProvider).go('/activity');
    invalidateMoneyIn(container);
    await _settle(tester);
    expect(find.text('Transfer to Japan Trip'), findsOneWidget);
    expect(find.text('→ ₱2,500'), findsOneWidget);
    await tester.drag(find.text('Transfer to Japan Trip'), const Offset(-600, 0));
    await _settle(tester);
    expect(find.text('Transfer to Japan Trip'), findsNothing);
    expect((await resolve(repo.goals())).firstWhere((g) => g.id == 1).saved, japanBefore);
  });

  testWidgets('a bill due tomorrow is a reminder on Home and in the bell, and paying it can be undone', (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final container = await _signedIn(tester, repo: repo);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    // Demo bills are 3+ days away: no reminder yet.
    expect(find.text('Mark paid'), findsNothing);

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final internet = await resolve(
      repo.addBill(BillDraft(title: 'Internet', amount: 1699, category: 'bills', frequency: 'monthly', nextDueOn: tomorrow)),
    );
    invalidateMoneyIn(container);
    await _settle(tester);
    expect(find.text('Internet'), findsWidgets);
    expect(find.text('Due tomorrow'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Mark paid'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications'));
    await _settle(tester);
    expect(find.text('REMINDERS'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Mark paid'), findsNWidgets(2));
    await tester.tapAt(const Offset(20, 20));
    await _settle(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Mark paid'));
    await _settle(tester);
    await tester.tap(find.text('Paid ₱1,699'));
    await _settle(tester);
    expect(find.textContaining('Internet paid'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Mark paid'), findsNothing);
    expect((await resolve(repo.transactions(month: now))).where((t) => t.title == 'Internet'), hasLength(1));

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(find.widgetWithText(TextButton, 'Mark paid'), findsOneWidget);
    expect((await resolve(repo.bills())).firstWhere((b) => b.id == internet.id).nextDueOn, tomorrow);
    expect((await resolve(repo.transactions(month: now))).where((t) => t.title == 'Internet'), isEmpty);
  });

  testWidgets('onboarding asks about you two and turns the answers into your nest', (tester) async {
    final repo = MockRepository(latency: Duration.zero, seed: false);
    final container = await _pumpApp(tester, {}, repo: repo);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    await tester.tap(find.text('Get Started'));
    await _settle(tester);
    expect(find.text('First, about you two'), findsOneWidget);
    // A name is required.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next')).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'What should we call you?'), 'Alex');
    await tester.enterText(find.widgetWithText(TextField, "Your partner's name (optional)"), 'Sam');
    await tester.tap(find.text('Married'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await _settle(tester);

    expect(find.text('What are you saving for?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Skip'), findsOneWidget);
    await tester.tap(find.text('Emergency fund'));
    await tester.tap(find.text('Travel'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await _settle(tester);

    expect(find.text('Any family plans ahead?'), findsOneWidget);
    await tester.tap(find.text('Having kids'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await _settle(tester);

    expect(find.text('How do you handle money?'), findsOneWidget);
    await tester.tap(find.text('Partly shared'));
    await tester.enterText(find.widgetWithText(TextField, 'Monthly shared budget (optional)'), '30000');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create my nest'));
    await _settle(tester);

    expect(find.text('Save your recovery key'), findsOneWidget);
    expect(find.text('K7QM-2WXP-9DTR-H4NB'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed, isNull);
    await tester.tap(find.text("I've saved my recovery key"));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await _settle(tester);

    expect(find.text("Hi Alex! Let's build your nest"), findsOneWidget);
    expect(find.text('Join Sam'), findsOneWidget);
    await tester.tap(find.text('Create our nest'));
    await _settle(tester);
    expect(find.text('Make it yours'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(find.text('Alex & Sam'), findsOneWidget);
    expect(find.text('₱30,000'), findsWidgets);
    final goals = (await resolve(repo.goals())).map((g) => g.name).toList();
    expect(goals, unorderedEquals(['Emergency Fund', 'Travel Fund', 'Baby Fund']));
    expect(container.read(sessionProvider).value!.couple!.stage, 'married');
  });

  testWidgets('a recovery key brings you back into your nest', (tester) async {
    await _pumpApp(tester, {});
    await tester.tap(find.text('I already have a nest'));
    await _settle(tester);
    expect(find.text('Back to your nest'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ABCD1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await _settle(tester);
    expect(find.text('Make it yours'), findsOneWidget, reason: 'an 8-character partner code signs you in');
  });

  testWidgets('a wrong recovery key is refused', (tester) async {
    await _pumpApp(tester, {});
    await tester.tap(find.text('I already have a nest'));
    await _settle(tester);
    await tester.tap(find.text('Recovery key').first);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'NOPE-NOPE-NOPE-NOPE');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await _settle(tester);
    expect(find.textContaining("doesn't match any nest"), findsOneWidget);
    expect(find.text('Back to your nest'), findsOneWidget);
  });

  testWidgets('Personalize re-links a phone and asks before removing this one', (tester) async {
    final container = await _signedIn(tester);
    container.read(routerProvider).go('/us/personalize');
    await _settle(tester);
    await tester.tap(find.text('Settings'));
    await _settle(tester);
    expect(find.textContaining('Anonymous: no email, no password'), findsOneWidget);

    await tester.tap(find.text('Re-link a phone'));
    await _settle(tester);
    expect(find.text('Re-link Sam'), findsOneWidget);
    expect(find.text('QX4M7KDP'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await _settle(tester);

    await tester.scrollUntilVisible(find.text('Remove this phone'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Remove this phone'));
    await _settle(tester);
    expect(find.text('Remove this phone?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(container.read(sessionProvider).value, isNotNull);
  });

  testWidgets("a goal's target can be edited", (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final container = await _signedIn(tester, repo: repo);
    container.read(routerProvider).go('/goals');
    await _settle(tester);

    await tester.tap(find.byTooltip('Options for New Home'));
    await _settle(tester);
    await tester.tap(find.text('Edit goal'));
    await _settle(tester);
    expect(find.text('Edit goal'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '2000000'), '2500000');
    await tester.tap(find.text('Save changes'));
    await _settle(tester);

    final goals = repo.goals();
    await _settle(tester);
    expect((await goals).firstWhere((g) => g.name == 'New Home').target, 2500000);
  });

  testWidgets('a transfer that completes a goal celebrates it', (tester) async {
    await _signedIn(tester);

    await tester.tap(find.text('Transfer'));
    await _settle(tester);
    await tester.tap(find.text('Emergency Fund').last);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '35000');
    await tester.pump();
    await tester.tap(find.text('Transfer ₱35,000 to Emergency Fund'));
    await _settle(tester);

    expect(find.text('You reached Emergency Fund!'), findsOneWidget);
    await tester.tap(find.text('Yay!'));
    await _settle(tester);
    expect(find.text('You reached Emergency Fund!'), findsNothing);
  });

  testWidgets('cancelling a goal releases its savings, and it can be restored', (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final container = await _signedIn(tester, repo: repo);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    container.read(routerProvider).go('/goals');
    await _settle(tester);
    await tester.scrollUntilVisible(find.byTooltip('Options for Japan Trip'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Options for Japan Trip'));
    await _settle(tester);
    await tester.tap(find.text('Cancel goal'));
    await _settle(tester);
    expect(find.text('Cancel Japan Trip?'), findsOneWidget);
    expect(find.textContaining('₱12,000 you saved will be released'), findsOneWidget);
    // Keep and Cancel sit side by side, Keep on the left.
    final keep = tester.getCenter(find.text('Keep goal'));
    final confirm = tester.getCenter(find.widgetWithText(FilledButton, 'Cancel goal'));
    expect(keep.dy, moreOrLessEquals(confirm.dy, epsilon: 1));
    expect(keep.dx, lessThan(confirm.dx));
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel goal'));
    await _settle(tester);

    expect(find.text('Japan Trip cancelled'), findsOneWidget);
    expect(find.byTooltip('Options for Japan Trip'), findsNothing);
    expect((await resolve(repo.transactions(month: DateTime.now()))).where((t) => t.isRelease), hasLength(1));

    // Undo (before the message times out) restores it straight away.
    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect((await resolve(repo.goals())).firstWhere((g) => g.name == 'Japan Trip').cancelled, isFalse);
    expect((await resolve(repo.transactions(month: DateTime.now()))).where((t) => t.isRelease), isEmpty);

    // Cancel again: the release is logged, and Japan Trip isn't offered for transfers.
    await resolve(repo.cancelGoal((await resolve(repo.goals())).firstWhere((g) => g.name == 'Japan Trip').id));
    invalidateMoneyIn(container);
    await _settle(tester);
    final txns = await resolve(repo.transactions(month: DateTime.now()));
    expect(txns.where((t) => t.isRelease && t.title == 'Released from Japan Trip' && t.amount == 12000), hasLength(1));
    final active = await resolve(container.read(activeGoalsProvider.future));
    expect(active.map((g) => g.name), isNot(contains('Japan Trip')));

    // Restore from the Cancelled section.
    await tester.scrollUntilVisible(find.text('Cancelled goals (1)'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Cancelled goals (1)'));
    await _settle(tester);
    expect(find.text('₱12,000 released · ${shortDate(DateTime.now())}'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Restore'), 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await _settle(tester);
    await tester.tap(find.text('Restore'));
    await _settle(tester);
    expect(find.text('Japan Trip is back'), findsOneWidget);
    expect(find.text('Cancelled goals (1)'), findsNothing);
  });

  testWidgets('Activity filters by category, payer and type, with matching totals', (tester) async {
    final container = await _signedIn(tester);
    container.read(routerProvider).go('/activity');
    await _settle(tester);
    expect(find.text('Electricity Bill'), findsOneWidget);

    // Sam's food only.
    await tester.tap(find.byTooltip('Filters'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Food & Dining'));
    await tester.tap(find.text('Sam').last);
    await tester.pump();
    await tester.tap(find.text('Show 1 result'));
    await _settle(tester);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Electricity Bill'), findsNothing);
    expect(find.text('1 transaction · ₱1,250 out'), findsOneWidget);
    expect(find.textContaining('left over in these results'), findsNothing, reason: 'more out than in');

    // Removing a chip widens the results again.
    // The chip row scrolls sideways; bring the chip's ✕ into view first.
    await tester.ensureVisible(find.widgetWithText(InputChip, 'Paid by Sam'));
    await _settle(tester);
    await tester.tap(find.descendant(of: find.widgetWithText(InputChip, 'Paid by Sam'), matching: find.byType(Icon)).last);
    await _settle(tester);
    expect(find.text('2 transactions · ₱5,050 out'), findsOneWidget, reason: 'both food entries');

    // Income only: just the salary, nothing out.
    await tester.tap(find.byTooltip('Filters'));
    await _settle(tester);
    await tester.tap(find.text('Reset'));
    await tester.tap(find.widgetWithText(FilterChip, 'Income'));
    await tester.pump();
    await tester.tap(find.text('Show 1 result'));
    await _settle(tester);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('1 transaction · ₱0 out'), findsOneWidget);

    // Nothing matches: income in the food category.
    await tester.tap(find.byTooltip('Filters'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Food & Dining'));
    await tester.pump();
    await tester.tap(find.text('Show 0 results'));
    await _settle(tester);
    expect(find.text('No matches'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await _settle(tester);
    expect(find.text('Electricity Bill'), findsOneWidget);
  });

  testWidgets('a custom date range spans months', (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final container = await _signedIn(tester, repo: repo);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 15);
    await resolve(
      repo.addTransaction(
        TxnDraft(
          type: 'expense',
          amount: 640,
          category: 'food',
          title: 'Old dinner',
          paymentMethod: 'cash',
          isSplit: true,
          occurredOn: lastMonth,
        ),
      ),
    );
    final thisMonth = await resolve(container.read(transactionsProvider((monthStart(now), '')).future));
    expect(thisMonth.map((t) => t.title), isNot(contains('Old dinner')));
    final range = await resolve(container.read(transactionsRangeProvider((DateTime(now.year, now.month - 1, 1), now, '')).future));
    expect(range.map((t) => t.title), containsAll(['Old dinner', 'Weekly groceries']));
  });

  testWidgets('you can add and remove your profile photo', (tester) async {
    // A 1×1 PNG stands in for the photo picker.
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAE0lEQVR4nGMM6ElhgAEmOAsvBwA/cAFIjcJkMQAAAABJRU5ErkJggg==');
    final repo = MockRepository(latency: Duration.zero);
    final container = await _signedIn(tester, repo: repo, overrides: [photoPickerProvider.overrideWithValue((_) async => png)]);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    bool hasPhoto() => find
        .byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).image != null)
        .evaluate()
        .isNotEmpty;
    expect(find.byType(MascotBadge), findsOneWidget);

    container.read(routerProvider).go('/us/personalize');
    await _settle(tester);
    await tester.tap(find.text('Settings'));
    await _settle(tester);
    expect(hasPhoto(), isFalse);
    await tester.tap(find.byTooltip('Change your photo'));
    await _settle(tester);
    expect(find.text('Remove photo'), findsNothing);
    await tester.tap(find.text('Choose photo'));
    await _settle(tester);

    expect(find.text('Photo updated'), findsOneWidget);
    expect(container.read(meProvider).user.avatarVersion, isNotNull);
    expect(await resolve(repo.avatar(1)), png);
    expect(hasPhoto(), isTrue);

    // Home's badge shows photos instead of the birds.
    container.read(routerProvider).go('/home');
    await _settle(tester);
    expect(find.byType(MascotBadge), findsNothing);
    expect(find.descendant(of: find.byType(CoupleBadge), matching: find.byType(Image)), findsOneWidget);

    // Remove it again.
    container.read(routerProvider).go('/us/personalize');
    await _settle(tester);
    await tester.tap(find.text('Settings'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Change your photo'));
    await _settle(tester);
    await tester.tap(find.text('Remove photo'));
    await _settle(tester);
    expect(find.text('Photo removed'), findsOneWidget);
    expect(container.read(meProvider).user.avatarVersion, isNull);
    container.read(routerProvider).go('/home');
    await _settle(tester);
    expect(find.byType(MascotBadge), findsOneWidget);
  });

  testWidgets('the monthly recap sums up the month and can be shared', (tester) async {
    Uint8List? shared;
    final container = await _signedIn(
      tester,
      overrides: [
        shareImageProvider.overrideWithValue((png, name) async {
          shared = png;
          return true;
        }),
      ],
    );
    container.read(routerProvider).go('/home/recap');
    await _settle(tester);

    expect(find.text('₱17,780 spent'), findsOneWidget);
    expect(find.text('of ₱32,000 budget · 56%'), findsOneWidget);
    expect(find.textContaining('under budget. Nicely done!'), findsOneWidget);
    expect(find.text('Bills & Utilities'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sam covered 51% of spending.'), 200, scrollable: find.byType(Scrollable).last);

    await tester.tap(find.byTooltip('Share recap'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await _settle(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await _settle(tester);
    expect(shared, isNotNull);
    expect(shared!.sublist(1, 4), 'PNG'.codeUnits, reason: 'a PNG image');

    // The month before has nothing logged.
    await tester.tap(find.byTooltip('Previous month'));
    await _settle(tester);
    expect(find.textContaining('Nothing to recap for'), findsOneWidget);
  });

  testWidgets('Activity opens the recap for the month you are looking at', (tester) async {
    final container = await _signedIn(tester);
    container.read(routerProvider).go('/activity');
    await _settle(tester);
    await tester.tap(find.byTooltip('Monthly recap'));
    await _settle(tester);
    expect(find.text('₱17,780 spent'), findsOneWidget);
  });

  testWidgets("in a month's first week Home offers last month's recap", (tester) async {
    final early = DateTime(2026, 11, 2);
    final container = await _signedIn(tester, overrides: [nowProvider.overrideWithValue(() => early)]);
    expect(find.text('Your October recap is ready'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss recap'));
    await _settle(tester);
    expect(find.text('Your October recap is ready'), findsNothing);
    expect(container.read(prefsProvider).getBool('recap_seen_2026-10'), isTrue);
  });

  testWidgets('no recap nudge after the first week', (tester) async {
    await _signedIn(tester, overrides: [nowProvider.overrideWithValue(() => DateTime(2026, 11, 12))]);
    expect(find.textContaining('recap is ready'), findsNothing);
  });

  // The demo seeds Alex's pay on the 15th & 30th and Sam's on the 25th, from tomorrow.
  DateTime seededPayday(List<int> days) {
    final now = DateTime.now();
    return firstPaydayOnOrAfter(days, DateTime(now.year, now.month, now.day + 1));
  }

  testWidgets('on payday Home asks to log it; the amount can change and Undo puts it back', (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final payday = seededPayday(const [15, 30]);
    await _signedIn(tester, repo: repo, overrides: [nowProvider.overrideWithValue(() => payday)]);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    expect(find.text('Payday! Log your Salary'), findsOneWidget);
    expect(find.text('₱22,500 · Payday today'), findsOneWidget);
    expect(find.text('Payday today'), findsNothing, reason: 'the card line steps aside for the strip');
    await tester.tap(find.text('Log it'));
    await _settle(tester);
    expect(find.text('Did your Salary come in?'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Amount received'), '23000');
    await _settle(tester);
    await tester.tap(find.text('Log ₱23,000'));
    await _settle(tester);

    expect(find.textContaining('Salary logged · next payday'), findsOneWidget);
    expect(find.text('Payday! Log your Salary'), findsNothing);
    final txns = await resolve(repo.transactions(month: DateTime.now()));
    expect(txns.where((t) => t.isIncome && t.title == 'Salary' && t.amount == 23000), hasLength(1));

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(find.text('Payday! Log your Salary'), findsOneWidget);
    final after = await resolve(repo.transactions(month: DateTime.now()));
    expect(after.where((t) => t.amount == 23000), isEmpty);
  });

  testWidgets('before payday the card shows when it is and what you can spend a day', (tester) async {
    final a = seededPayday(const [15, 30]);
    final b = seededPayday(const [25]);
    final soonest = a.isBefore(b) ? a : b;
    await _signedIn(tester, overrides: [nowProvider.overrideWithValue(() => soonest.subtract(const Duration(days: 3)))]);
    expect(find.textContaining('recap is ready'), findsNothing);
    expect(find.text('Payday! Log your Salary'), findsNothing);
    expect(find.text('Payday in 3 days'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^₱[\d,]+ a day$'), findRichText: true), findsOneWidget);
  });

  testWidgets("a partner's payday is never nagged, and only your own can be logged", (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final sams = seededPayday(const [25]);
    final container = await _signedIn(tester, repo: repo, overrides: [nowProvider.overrideWithValue(() => sams)]);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    // With only Sam's payday left, nothing asks Alex to log it.
    await resolve(repo.deletePayday(1));
    container.invalidate(dashboardProvider);
    await _settle(tester);
    expect(find.text('Payday! Log your Salary'), findsNothing);
    expect(find.text('Payday today'), findsOneWidget);

    container.read(routerProvider).go('/home/budgets');
    await _settle(tester);
    await tester.scrollUntilVisible(find.text("Sam's Salary"), 200, scrollable: find.byType(Scrollable).last);
    expect(find.byTooltip('Log Salary'), findsNothing);
    expect(find.textContaining('Monthly · 25th'), findsOneWidget);
  });

  testWidgets('a payday can be added from the Budgets page', (tester) async {
    final container = await _signedIn(tester);
    container.read(routerProvider).go('/home/budgets');
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Paydays'), 200, scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Add payday'));
    await _settle(tester);
    await tester.tap(find.text('Add payday'));
    await _settle(tester);
    expect(find.text('New payday'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Freelance');
    await tester.enterText(find.widgetWithText(TextField, 'Usual take-home pay'), '5000');
    await tester.tap(find.text('Weekly'));
    await _settle(tester);
    expect(find.text('Next payday'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add payday'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add payday'));
    await _settle(tester);

    expect(find.text('New payday'), findsNothing);
    await tester.scrollUntilVisible(find.text('Freelance'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Every week'), findsOneWidget);
    expect(find.byTooltip('Log Freelance'), findsOneWidget);
  });

  testWidgets('Home shows each wallet as a small card, and the Wallets page as full cards', (tester) async {
    final container = await _signedIn(tester);
    await tester.scrollUntilVisible(find.text('Wallets'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.bySemanticsLabel('Our Maya, ₱6,000'), findsOneWidget);
    expect(find.bySemanticsLabel('BPI Credit, ₱6,300 owed'), findsOneWidget);

    await tester.ensureVisible(find.bySemanticsLabel('GCash, ₱4,200'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('GCash, ₱4,200'));
    await _settle(tester);
    expect(find.text('Our Wallets'), findsOneWidget);
    expect(find.text('₱10,200 across 3 wallets · ₱6,300 owed on cards', findRichText: true), findsOneWidget);
    // Opens on the card that was tapped: its month below.
    expect(find.text('Electricity Bill'), findsOneWidget);
    expect(find.text('Correct balance'), findsOneWidget);

    await tester.tap(find.text("Sam's"));
    await _settle(tester);
    // Sam keeps the BDO balance private.
    expect(find.text('Balance private'), findsOneWidget);
    expect(find.textContaining('Sam keeps this wallet'), findsOneWidget);
    expect(find.text('Correct balance'), findsNothing);
    expect(container.read(routerProvider).state.uri.path, '/home/wallets');
  });

  testWidgets('a new wallet is added with its brand, and spending from it lowers its balance', (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final container = await _signedIn(tester, repo: repo);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    container.read(routerProvider).go('/home/wallets');
    await _settle(tester);
    await tester.tap(find.byTooltip('Add wallet'));
    await _settle(tester);
    expect(find.text('New wallet'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('MariBank'));
    await _settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Balance now'), '2500');
    await _settle(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add MariBank'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add MariBank'));
    await _settle(tester);
    final mari = (await resolve(repo.wallets())).firstWhere((w) => w.name == 'MariBank');
    expect(mari.provider, 'maribank');
    expect(mari.kind, 'debit');
    expect(mari.balance, 2500);

    // Log a ₱300 expense paid with it.
    container.read(routerProvider).push('/add');
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, '300');
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'MariBank'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'MariBank'));
    await _settle(tester);
    await tester.tap(find.text('Save'));
    await _settle(tester);
    final after = (await resolve(repo.wallets())).firstWhere((w) => w.id == mari.id);
    expect(after.balance, 2200);
    expect(container.read(prefsProvider).getInt('last_wallet_id'), mari.id);

    // Next time it's already picked.
    container.read(routerProvider).push('/add');
    await _settle(tester);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'MariBank'));
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'MariBank')).selected, isTrue);
  });

  testWidgets("a wallet's balance can be corrected, and a shared wallet means shared spending", (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final container = await _signedIn(tester, repo: repo);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    container.read(routerProvider).go('/home/wallets?id=2');
    await _settle(tester);
    await tester.tap(find.text('Correct balance'));
    await _settle(tester);
    expect(find.text('Correct GCash'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Balance'), '3950');
    await tester.tap(find.text('Save balance'));
    await _settle(tester);
    expect(find.text('GCash balance updated'), findsOneWidget);
    expect((await resolve(repo.wallets())).firstWhere((w) => w.id == 2).balance, 3950);

    container.read(routerProvider).push('/add');
    await _settle(tester);
    expect(find.text('Paid by'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Our Maya · Ours'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Our Maya · Ours'));
    await _settle(tester);
    expect(find.text('Paid by'), findsNothing, reason: 'it came from the shared pot');
    // Sam's private BDO isn't offered to Alex.
    expect(find.widgetWithText(ChoiceChip, 'BDO Debit'), findsNothing);
  });

  testWidgets('with no wallets yet, Home and the Wallets page invite you to add one', (tester) async {
    final container = await _signedIn(tester, repo: MockRepository(latency: Duration.zero, seed: false));
    await tester.scrollUntilVisible(find.text('Add your wallets'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Add your wallets'));
    await _settle(tester);
    expect(container.read(routerProvider).state.uri.path, '/home/wallets');
    expect(find.text('Every peso, in one place'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Add GCash'));
    await _settle(tester);
    expect(find.text('New wallet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add GCash'), findsOneWidget);
  });

  testWidgets('swiping or tapping the next card shows that wallet', (tester) async {
    final container = await _signedIn(tester);
    container.read(routerProvider).go('/home/wallets');
    await _settle(tester);
    expect(find.text('Our share'), findsOneWidget, reason: "Our Maya first, with Sam's top-up");
    // Only its left edge peeks in.
    await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('wallet-card-2'))) + const Offset(16, 100));
    await _settle(tester);
    expect(find.text('Electricity Bill'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await _settle(tester);
    expect(find.text('Weekly groceries'), findsOneWidget, reason: 'then the BPI card');
  });

  testWidgets('topping up the shared wallet moves money without spending it, and Undo reverses it', (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final container = await _signedIn(tester, repo: repo);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    container.read(routerProvider).go('/home/wallets');
    await _settle(tester);
    await tester.tap(find.text('Top up'));
    await _settle(tester);
    expect(find.text('Top up Our Maya'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '2000');
    await _settle(tester);
    await tester.tap(find.text('Move ₱2,000'));
    await _settle(tester);
    expect(find.text('Moved ₱2,000 to Our Maya'), findsOneWidget);

    var wallets = await resolve(repo.wallets());
    expect(wallets.firstWhere((w) => w.name == 'Our Maya').balance, 8000);
    expect(wallets.firstWhere((w) => w.name == 'GCash').balance, 2200);
    await tester.tap(find.text('Undo'));
    await _settle(tester);
    wallets = await resolve(repo.wallets());
    expect(wallets.firstWhere((w) => w.name == 'GCash').balance, 4200);

    await resolve(repo.moveMoney(fromWalletId: 2, toWalletId: 1, amount: 2000));
    // Not spending: the budget is untouched.
    expect((await resolve(repo.dashboard())).budget.spent, 17780);
    // Settle Up lists who put money in.
    final balance = await resolve(repo.balance());
    expect(balance.members.firstWhere((m) => m.name == 'Alex').toppedUpThisMonth, 2000);
    expect(balance.members.firstWhere((m) => m.name == 'Sam').toppedUpThisMonth, 3000);
    expect(balance.owes!.amount, 415, reason: 'top-ups never change who owes whom');
    container.read(routerProvider).go('/home/settle');
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Put into shared wallets'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Put into shared wallets'), findsOneWidget);
  });

  testWidgets('a credit card can be paid off from another wallet', (tester) async {
    final repo = MockRepository(latency: Duration.zero);
    final container = await _signedIn(tester, repo: repo);
    Future<T> resolve<T>(Future<T> f) async {
      await _settle(tester);
      return f;
    }

    container.read(routerProvider).go('/home/wallets?id=3');
    await _settle(tester);
    await tester.tap(find.text('Pay card'));
    await _settle(tester);
    expect(find.text('Pay BPI Credit'), findsOneWidget);
    // The amount owed is suggested.
    await tester.tap(find.text('Move ₱6,300'));
    await _settle(tester);
    final wallets = await resolve(repo.wallets());
    expect(wallets.firstWhere((w) => w.name == 'BPI Credit').balance, 0);

    container.read(routerProvider).go('/activity');
    await _settle(tester);
    expect(find.text('⇄ ₱6,300'), findsWidgets);
    expect(find.textContaining('Moved between wallets'), findsWidgets);
  });
}
