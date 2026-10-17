import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/mascot/mascot_controller.dart';
import '../core/theme/palettes.dart';
import 'api_repository.dart';
import 'mock_repository.dart';
import 'models.dart';
import 'repository.dart';

/// Set with `--dart-define=API_URL=https://api.example.com/api/v1`.
/// When empty the app runs on in-memory demo data.
const apiUrl = String.fromEnvironment('API_URL');

final repositoryProvider = Provider<PairnestRepository>((ref) => apiUrl.isEmpty ? MockRepository() : ApiRepository(apiUrl));

/// Overridden in `main()` with the loaded instance.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

/// Lets tests skip network font loading.
final useGoogleFontsProvider = Provider<bool>((ref) => true);

class FlagNotifier extends Notifier<bool> {
  FlagNotifier(this.key);

  final String key;

  @override
  bool build() => ref.read(prefsProvider).getBool(key) ?? false;

  void set() {
    ref.read(prefsProvider).setBool(key, true);
    state = true;
  }
}

final onboardedProvider = NotifierProvider<FlagNotifier, bool>(() => FlagNotifier('onboarded'));
final themeChosenProvider = NotifierProvider<FlagNotifier, bool>(() => FlagNotifier('theme_chosen'));

class ThemeNotifier extends Notifier<PairnestPalette> {
  static const _key = 'theme';

  @override
  PairnestPalette build() => paletteById(ref.read(prefsProvider).getString(_key));

  /// Applies a palette locally; [share] also saves it for the partner.
  Future<void> select(String id, {bool share = false}) async {
    state = paletteById(id);
    await ref.read(prefsProvider).setString(_key, id);
    if (share) await ref.read(repositoryProvider).updateTheme(id);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, PairnestPalette>(ThemeNotifier.new);

class SessionNotifier extends AsyncNotifier<Me?> {
  PairnestRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<Me?> build() async {
    final me = await _repo.restoreSession();
    _syncTheme(me);
    return me;
  }

  void _syncTheme(Me? me) {
    final theme = me?.couple?.theme;
    if (theme != null) ref.read(themeProvider.notifier).select(theme);
  }

  Future<void> _run(Future<Me> Function() action) async {
    final me = await action();
    _syncTheme(me);
    state = AsyncData(me);
  }

  /// Onboarding. The recovery key waits in [pendingRecoveryKeyProvider] until
  /// the user has seen it.
  Future<void> start(String name, OnboardingProfile profile) => _run(() async {
    final result = await _repo.start(name, profile);
    ref.read(pendingRecoveryKeyProvider.notifier).show(result.recoveryKey);
    return result.me;
  });

  Future<void> recover(String key) => _run(() => _repo.recover(key));

  /// Replaces the signed-in user, e.g. after a new profile photo.
  void updateMe(Me me) => state = AsyncData(me);

  Future<void> redeemRelink(String code) => _run(() => _repo.redeemRelink(code));

  Future<void> createNest() => _run(() => _repo.createNest(ref.read(themeProvider).id));

  Future<void> joinNest(String code) => _run(() => _repo.joinNest(code));

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Me?>(SessionNotifier.new);

/// A recovery key just issued at onboarding, until the user confirms they saved it.
class PendingRecoveryKey extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String key) => state = key;

  void saved() => state = null;
}

final pendingRecoveryKeyProvider = NotifierProvider<PendingRecoveryKey, String?>(PendingRecoveryKey.new);

Me? _lastMe;

/// The signed-in user; only read this inside the paired part of the app.
/// Holds the last value briefly after sign-out so screens don't crash
/// in the frame before the router redirects away.
final meProvider = Provider<Me>((ref) {
  final me = ref.watch(sessionProvider).value;
  if (me != null) _lastMe = me;
  return me ?? _lastMe ?? const Me(user: Member(id: 0, name: ''));
});

final dashboardProvider = FutureProvider<Dashboard>((ref) => ref.watch(repositoryProvider).dashboard());

final feedProvider = FutureProvider<List<FeedItem>>((ref) => ref.watch(repositoryProvider).feed());

/// When the bell's feed was last opened; newer items light up the dot.
class FeedSeenNotifier extends Notifier<DateTime?> {
  static const _key = 'feed_seen_at';

  @override
  DateTime? build() {
    final ms = ref.read(prefsProvider).getInt(_key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  void markSeen() {
    final now = DateTime.now();
    ref.read(prefsProvider).setInt(_key, now.millisecondsSinceEpoch);
    state = now;
  }
}

final feedSeenProvider = NotifierProvider<FeedSeenNotifier, DateTime?>(FeedSeenNotifier.new);

final hasUnseenFeedProvider = Provider<bool>((ref) {
  final items = ref.watch(feedProvider).value ?? const <FeedItem>[];
  final seen = ref.watch(feedSeenProvider);
  return items.isNotEmpty && (seen == null || items.first.at.isAfter(seen));
});

/// Upcoming bills that are overdue, due today or due tomorrow.
final dueBillsProvider = Provider<List<Bill>>((ref) {
  final bills = ref.watch(dashboardProvider).value?.upcomingBills ?? const <Bill>[];
  return [
    for (final b in bills)
      if (b.needsAttention()) b,
  ];
});

/// Due bills light the bell until it's been opened today.
final hasDueRemindersProvider = Provider<bool>((ref) {
  if (ref.watch(dueBillsProvider).isEmpty) return false;
  final seen = ref.watch(feedSeenProvider);
  final now = DateTime.now();
  return seen == null || seen.isBefore(DateTime(now.year, now.month, now.day));
});

/// A member's photo bytes, keyed by its version so a new photo is refetched
/// and an unchanged one stays cached.
final avatarProvider = FutureProvider.family<Uint8List?, (int, int)>((ref, key) => ref.watch(repositoryProvider).avatar(key.$1));

/// Picks a photo from the gallery or camera; overridden in tests.
final photoPickerProvider = Provider<Future<Uint8List?> Function(ImageSource source)>((ref) {
  return (source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    return file?.readAsBytes();
  };
});

/// Lets app events make the Home and Us birds react (glance, cheer, celebrate).
final mascotControllerProvider = Provider<MascotController>((ref) {
  final controller = MascotController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// The eye toggle on the balance card: hide amounts when others can see the screen.
class HideAmountsNotifier extends Notifier<bool> {
  static const _key = 'hide_amounts';

  @override
  bool build() => ref.read(prefsProvider).getBool(_key) ?? false;

  void toggle() {
    state = !state;
    ref.read(prefsProvider).setBool(_key, state);
  }
}

final hideAmountsProvider = NotifierProvider<HideAmountsNotifier, bool>(HideAmountsNotifier.new);

final transactionsProvider = FutureProvider.family<List<Txn>, (DateTime, String)>(
  (ref, args) => ref.watch(repositoryProvider).transactions(month: args.$1, query: args.$2),
);

/// Transactions between two days (inclusive), for Activity's custom range.
final transactionsRangeProvider = FutureProvider.family<List<Txn>, (DateTime, DateTime, String)>(
  (ref, args) => ref.watch(repositoryProvider).transactions(from: args.$1, to: args.$2, query: args.$3),
);

final budgetProvider = FutureProvider.family<BudgetSummary, DateTime>(
  (ref, month) => ref.watch(repositoryProvider).budget(monthStart(month)),
);

final goalsProvider = FutureProvider<List<Goal>>((ref) => ref.watch(repositoryProvider).goals());

/// Goals still being saved for (cancelled ones left out).
final activeGoalsProvider = FutureProvider<List<Goal>>(
  (ref) async => [
    for (final g in await ref.watch(goalsProvider.future))
      if (!g.cancelled) g,
  ],
);

final moodsProvider = FutureProvider<List<Mood>>((ref) => ref.watch(repositoryProvider).moods());

final talkProvider = FutureProvider<TalkState>((ref) => ref.watch(repositoryProvider).currentTalk());

final talkHistoryProvider = FutureProvider<List<PastTalk>>((ref) => ref.watch(repositoryProvider).talkHistory());

final billsProvider = FutureProvider<List<Bill>>((ref) => ref.watch(repositoryProvider).bills());

final balanceProvider = FutureProvider<SplitBalance>((ref) => ref.watch(repositoryProvider).balance());

final plansProvider = FutureProvider<List<Plan>>((ref) => ref.watch(repositoryProvider).plans());

/// Providers that depend on transactions.
final _moneyProviders = <ProviderOrFamily>[
  dashboardProvider,
  feedProvider,
  transactionsProvider,
  transactionsRangeProvider,
  budgetProvider,
  billsProvider,
  balanceProvider,
  goalsProvider,
];

/// Refresh everything that depends on transactions after a money change.
void invalidateMoney(WidgetRef ref) {
  for (final p in _moneyProviders) {
    ref.invalidate(p);
  }
}

/// [invalidateMoney] for code that outlives its widget, such as a snackbar's
/// Undo after the sheet that showed it has closed.
void invalidateMoneyIn(ProviderContainer container) {
  for (final p in _moneyProviders) {
    container.invalidate(p);
  }
}
