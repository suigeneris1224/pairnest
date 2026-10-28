import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/pref_keys.dart';
import '../core/mascot/mascot_controller.dart';
import '../features/recap/monthly_recap.dart';
import '../core/theme/palettes.dart';
import 'api_repository.dart';
import 'mock_repository.dart';
import 'models.dart';
import 'repository.dart';

/// Set with `--dart-define=API_URL=https://api.example.com/api/v1`.
/// When empty the app runs on in-memory demo data, which a release build
/// refuses: shipping the demo by mistake would look like a working app.
const apiUrl = String.fromEnvironment('API_URL');

final repositoryProvider = Provider<PairnestRepository>((ref) {
  if (apiUrl.isEmpty) {
    if (kReleaseMode && !kIsWeb) throw StateError('Release builds need --dart-define=API_URL=https://...');
    return MockRepository();
  }
  // A token rejected mid-session (this phone was removed, or it expired)
  // signs out here instead of leaving every screen on an error.
  return ApiRepository(apiUrl, onSignedOut: () => ref.read(sessionProvider.notifier).signedOut());
});

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

final onboardedProvider = NotifierProvider<FlagNotifier, bool>(() => FlagNotifier(PrefKeys.onboarded));
final themeChosenProvider = NotifierProvider<FlagNotifier, bool>(() => FlagNotifier(PrefKeys.themeChosen));

class ThemeNotifier extends Notifier<PairnestPalette> {
  static const _key = PrefKeys.theme;

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
    signedOut();
  }

  /// Forgets everything the account loaded or remembered on this phone, so
  /// whoever signs in next starts clean. This phone's own choices (theme,
  /// hidden amounts) stay.
  void signedOut() {
    for (final p in _accountProviders) {
      ref.invalidate(p);
    }
    final prefs = ref.read(prefsProvider);
    for (final key in prefs.getKeys().where(PrefKeys.isAccountKey).toList()) {
      prefs.remove(key);
    }
    ref.invalidate(feedSeenProvider);
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
  static const _key = PrefKeys.feedSeenAt;

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

/// Today, injectable so tests and previews can pretend it's another day.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// A month's recap, built on the device from data already loaded elsewhere.
final recapProvider = FutureProvider.family<MonthlyRecap, DateTime>((ref, month) async {
  final m = monthStart(month);
  final results = await Future.wait([
    ref.watch(transactionsProvider((m, '')).future),
    ref.watch(transactionsProvider((DateTime(m.year, m.month - 1), '')).future),
  ]);
  final budget = await ref.watch(budgetProvider(m).future);
  final goals = await ref.watch(goalsProvider.future);
  final moods = await ref.watch(moodsProvider.future);
  final wallets = await ref.watch(walletsProvider.future);
  return MonthlyRecap.build(
    month: m,
    txns: results[0],
    previousTxns: results[1],
    budget: budget,
    goals: goals,
    moods: moods,
    members: ref.read(meProvider).couple?.members ?? const [],
    sharedWalletIds: {for (final w in wallets.where((w) => w.isShared)) w.id},
  );
});

/// Shares a PNG (or downloads it where sharing isn't available). Returns
/// true when the system share sheet handled it; overridden in tests.
final shareImageProvider = Provider<Future<bool> Function(Uint8List png, String name)>((ref) {
  return (png, name) async {
    final file = XFile.fromData(png, mimeType: 'image/png', name: name);
    // Desktop browsers can't reliably share files; a download is what people expect there.
    final desktopWeb = kIsWeb && defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS;
    if (desktopWeb) {
      await file.saveTo(name);
      return false;
    }
    try {
      await SharePlus.instance.share(ShareParams(files: [file], fileNameOverrides: [name]));
      return true;
    } catch (_) {
      await file.saveTo(name);
      return false;
    }
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
  static const _key = PrefKeys.hideAmounts;

  @override
  bool build() => ref.read(prefsProvider).getBool(_key) ?? false;

  void toggle() {
    state = !state;
    ref.read(prefsProvider).setBool(_key, state);
  }
}

final hideAmountsProvider = NotifierProvider<HideAmountsNotifier, bool>(HideAmountsNotifier.new);

/// Keeps an auto-disposing provider for [duration] after its last listener
/// goes, so flipping between months is instant but every search term and
/// range ever typed isn't kept forever.
void _cacheFor(Ref ref, [Duration duration = const Duration(minutes: 5)]) {
  final link = ref.keepAlive();
  Timer? timer;
  ref.onCancel(() => timer = Timer(duration, link.close));
  ref.onResume(() => timer?.cancel());
  ref.onDispose(() => timer?.cancel());
}

final transactionsProvider = FutureProvider.autoDispose.family<List<Txn>, (DateTime, String)>((ref, args) {
  _cacheFor(ref);
  return ref.watch(repositoryProvider).transactions(month: args.$1, query: args.$2);
});

/// Transactions between two days (inclusive), for Activity's custom range.
final transactionsRangeProvider = FutureProvider.autoDispose.family<List<Txn>, (DateTime, DateTime, String)>((ref, args) {
  _cacheFor(ref);
  return ref.watch(repositoryProvider).transactions(from: args.$1, to: args.$2, query: args.$3);
});

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

final paydaysProvider = FutureProvider<List<Payday>>((ref) => ref.watch(repositoryProvider).paydays());

final walletsProvider = FutureProvider<List<Wallet>>((ref) => ref.watch(repositoryProvider).wallets());

/// My paydays that have come and aren't logged yet. A partner's are never nagged.
final duePaydaysProvider = Provider<List<Payday>>((ref) {
  final paydays = ref.watch(dashboardProvider).value?.paydays ?? const <Payday>[];
  final me = ref.watch(meProvider).user.id;
  final now = ref.watch(nowProvider)();
  return [
    for (final d in paydays)
      if (d.userId == me && d.isDue(now)) d,
  ];
});

/// The soonest payday that hasn't passed, for either partner.
final nextPaydayProvider = Provider<Payday?>((ref) {
  final paydays = ref.watch(dashboardProvider).value?.paydays ?? const <Payday>[];
  final now = ref.watch(nowProvider)();
  return paydays.where((d) => d.daysUntil(now) >= 0).fold<Payday?>(null, (a, d) => a == null || d.nextOn.isBefore(a.nextOn) ? d : a);
});

final balanceProvider = FutureProvider<SplitBalance>((ref) => ref.watch(repositoryProvider).balance());

final plansProvider = FutureProvider<List<Plan>>((ref) => ref.watch(repositoryProvider).plans());

/// The phones signed in to your account.
final devicesProvider = FutureProvider.autoDispose<List<Device>>((ref) => ref.watch(repositoryProvider).devices());

/// Providers that depend on transactions.
final _moneyProviders = <ProviderOrFamily>[
  dashboardProvider,
  feedProvider,
  transactionsProvider,
  transactionsRangeProvider,
  budgetProvider,
  billsProvider,
  paydaysProvider,
  walletsProvider,
  balanceProvider,
  goalsProvider,
];

/// Everything loaded for the signed-in account, dropped when it signs out.
final _accountProviders = <ProviderOrFamily>[
  ..._moneyProviders,
  moodsProvider,
  talkProvider,
  talkHistoryProvider,
  plansProvider,
  recapProvider,
  avatarProvider,
  devicesProvider,
  pendingRecoveryKeyProvider,
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
