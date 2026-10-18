import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/motion/motion.dart';
import 'data/models.dart';
import 'data/providers.dart';
import 'features/activity/activity_screen.dart';
import 'features/auth/pair_screen.dart';
import 'features/budgets/budgets_screen.dart';
import 'features/expense/add_transaction_screen.dart';
import 'features/recap/recap_screen.dart';
import 'features/settle/settle_screen.dart';
import 'features/wallets/wallets_screen.dart';
import 'features/feelings/check_in_screen.dart';
import 'features/feelings/feelings_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/recovery_key_screen.dart';
import 'features/onboarding/restore_screen.dart';
import 'features/planner/planner_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/talks/money_talks_screen.dart';
import 'features/theme_select/theme_select_screen.dart';
import 'features/us/personalize_screen.dart';
import 'features/us/us_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

const _setupRoutes = ['/splash', '/onboarding', '/restore', '/recovery-key', '/pair', '/theme'];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  void bump(Object? _, Object? _) => refresh.value++;
  ref.listen(sessionProvider, bump);
  ref.listen<String?>(pendingRecoveryKeyProvider, (_, _) => refresh.value++);
  ref.listen(themeChosenProvider, bump);
  ref.onDispose(refresh.dispose);

  String? guard(String loc, String target) => loc == target ? null : target;

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final session = ref.read(sessionProvider);
      if (session.isLoading && !session.hasValue) {
        // Remember deep links (e.g. /#/goals on web) while the session loads.
        if (loc == '/splash') return null;
        return _setupRoutes.contains(loc) && loc != '/restore' ? '/splash' : '/splash?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      final me = session.value;
      // No account yet: onboarding, or getting back into an existing nest.
      if (me == null) {
        if (loc == '/onboarding' || loc == '/restore') return null;
        return state.uri.queryParameters['from'] == '/restore' ? '/restore' : '/onboarding';
      }
      if (ref.read(pendingRecoveryKeyProvider) != null) return guard(loc, '/recovery-key');
      if (me.couple == null) return guard(loc, '/pair');
      if (!ref.read(themeChosenProvider)) return guard(loc, '/theme');
      if (!_setupRoutes.contains(loc)) return null;
      final from = state.uri.queryParameters['from'];
      return from != null && from.startsWith('/') && !_setupRoutes.contains(Uri.parse(from).path) ? from : '/home';
    },
    routes: [
      GoRoute(path: '/splash', pageBuilder: (_, state) => _page(state, const SplashScreen())),
      GoRoute(path: '/onboarding', pageBuilder: (_, state) => _page(state, const OnboardingScreen())),
      GoRoute(path: '/restore', pageBuilder: (_, state) => _page(state, const RestoreScreen())),
      GoRoute(path: '/recovery-key', pageBuilder: (_, state) => _page(state, const RecoveryKeyScreen())),
      GoRoute(path: '/pair', pageBuilder: (_, state) => _page(state, const PairScreen())),
      GoRoute(path: '/theme', pageBuilder: (_, state) => _page(state, const ThemeSelectScreen())),
      GoRoute(
        path: '/add',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, state) {
          final type = state.uri.queryParameters['type'] ?? 'expense';
          final existing = state.extra is Txn ? state.extra as Txn : null;
          return _page(
            state,
            AddTransactionScreen(key: ValueKey('$type-${existing?.id}'), initialType: type, existing: existing),
            sheet: true,
          );
        },
      ),
      StatefulShellRoute(
        builder: (_, _, shell) => MainShell(shell: shell),
        navigatorContainerBuilder: (_, shell, children) => _FadingBranches(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (_, state) => _page(state, const HomeScreen()),
                routes: [
                  GoRoute(path: 'budgets', pageBuilder: (_, state) => _page(state, const BudgetsScreen())),
                  GoRoute(path: 'settle', pageBuilder: (_, state) => _page(state, const SettleScreen())),
                  GoRoute(
                    path: 'wallets',
                    pageBuilder: (_, state) => _page(state, WalletsScreen(initialId: int.tryParse(state.uri.queryParameters['id'] ?? ''))),
                  ),
                  GoRoute(
                    path: 'recap',
                    pageBuilder: (_, state) {
                      final m = DateTime.tryParse('${state.uri.queryParameters['month'] ?? ''}-01');
                      return _page(state, RecapScreen(key: ValueKey(m), month: m));
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/activity', pageBuilder: (_, state) => _page(state, const ActivityScreen()))],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/goals',
                pageBuilder: (_, state) => _page(state, GoalsScreen(openNew: state.uri.queryParameters['new'] != null)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feelings',
                pageBuilder: (_, state) => _page(state, const FeelingsScreen()),
                routes: [
                  GoRoute(
                    path: 'check-in',
                    pageBuilder: (_, state) => _page(state, CheckInScreen(initialMood: state.uri.queryParameters['mood'])),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/us',
                pageBuilder: (_, state) => _page(state, const UsScreen()),
                routes: [
                  GoRoute(path: 'planner', pageBuilder: (_, state) => _page(state, const PlannerScreen())),
                  GoRoute(path: 'talks', pageBuilder: (_, state) => _page(state, const MoneyTalksScreen())),
                  GoRoute(path: 'personalize', pageBuilder: (_, state) => _page(state, const PersonalizeScreen())),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Fade + slight rise between screens; [sheet] screens slide up from below.
Page<void> _page(GoRouterState state, Widget child, {bool sheet = false}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.medium,
    reverseTransitionDuration: Motion.fast + const Duration(milliseconds: 60),
    transitionsBuilder: (context, animation, secondary, child) {
      if (Motion.reduced(context)) return child;
      final curved = CurvedAnimation(parent: animation, curve: Motion.curve, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: Offset(0, sheet ? 0.12 : 0.03), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Crossfades between bottom-nav tabs while keeping each tab's state alive.
class _FadingBranches extends StatelessWidget {
  const _FadingBranches({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.reduced(context) ? Duration.zero : Motion.medium;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            // The fade must sit outside TickerMode: a muted ticker would freeze
            // the outgoing tab's fade-out and leave it covering the new tab.
            child: AnimatedOpacity(
              opacity: i == index ? 1 : 0,
              duration: duration,
              curve: Motion.curve,
              child: TickerMode(enabled: i == index, child: children[i]),
            ),
          ),
      ],
    );
  }
}
