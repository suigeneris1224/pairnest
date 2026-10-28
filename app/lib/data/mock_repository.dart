import 'dart:math' as math;
import 'dart:typed_data';

import '../core/format.dart';
import '../core/onboarding_options.dart';
import 'models.dart';
import 'payday_schedule.dart';
import 'repository.dart';

/// In-memory demo data mirroring the design mockup (Alex & Sam).
/// Used when the app is run without `--dart-define=API_URL=...`.
class MockRepository implements PairnestRepository {
  /// [seed] false starts a brand-new couple with no data, for empty states.
  MockRepository({this.latency = const Duration(milliseconds: 250), bool seed = true}) {
    if (seed) _seed();
  }

  final Duration latency;

  Me? _me;
  Member _user = const Member(id: 1, name: 'Alex');
  static const _sam = Member(id: 2, name: 'Sam');
  OnboardingProfile _profile = const OnboardingProfile();
  final _avatars = <int, Uint8List>{};
  Couple? _couple;
  int _nextId = 100;

  final _txns = <Txn>[];
  final _budgets = <String, (double, Map<String, double>)>{};
  final _goals = <Goal>[];
  final _moods = <Mood>[];
  final _plans = <Plan>[];
  final _bills = <Bill>[];
  final _paydays = <Payday>[];
  final _wallets = <Wallet>[];
  final _openings = <int, double>{};
  final _settlements = <Settlement>[];
  final _answers = <int, List<TalkAnswer>>{};
  final _prompts = const [
    Prompt(id: 1, topic: 'dreams', question: "What's one thing you'd love to save for together this year?"),
    Prompt(id: 2, topic: 'worries', question: 'Is there anything about our budget that worries you?'),
    Prompt(id: 3, topic: 'reflection', question: 'What made you happiest with our spending this week?'),
  ];
  final _pastTalkDates = <int, DateTime>{};

  Future<T> _delay<T>(T Function() fn) => Future.delayed(latency, fn);

  void _seed() {
    final now = DateTime.now();
    final m = monthStart(now);
    final today = DateTime(now.year, now.month, now.day);
    // From tomorrow, so the demo never opens on an unlogged payday.
    final tomorrow = today.add(const Duration(days: 1));
    _paydays.addAll([
      Payday(
        id: 1,
        userId: _user.id,
        userName: _user.name,
        title: 'Salary',
        amount: 22500,
        frequency: 'semimonthly',
        days: const [15, 30],
        nextOn: firstPaydayOnOrAfter(const [15, 30], tomorrow),
      ),
      Payday(
        id: 2,
        userId: _sam.id,
        userName: _sam.name,
        title: 'Salary',
        amount: 28000,
        frequency: 'monthly',
        days: const [25],
        nextOn: firstPaydayOnOrAfter(const [25], tomorrow),
      ),
    ]);
    _bills.addAll([
      Bill(
        id: 1,
        title: 'Rent',
        amount: 15000,
        category: 'bills',
        frequency: 'monthly',
        nextDueOn: today.add(const Duration(days: 3)),
        userName: 'Alex',
      ),
      Bill(
        id: 2,
        title: 'Netflix',
        amount: 549,
        category: 'entertainment',
        frequency: 'monthly',
        nextDueOn: today.add(const Duration(days: 6)),
        userName: 'Sam',
      ),
      Bill(
        id: 3,
        title: 'Meralco',
        amount: 2600,
        category: 'bills',
        frequency: 'monthly',
        nextDueOn: today.add(const Duration(days: 12)),
        userName: 'Alex',
      ),
    ]);
    DateTime day(int d) => DateTime(m.year, m.month, d.clamp(1, 28));

    _budgets[monthKey(m)] = (32000, {'food': 8000, 'bills': 6000, 'transport': 4000, 'shopping': 4000, 'entertainment': 3000});

    Txn t(int id, Member who, String type, double amount, String cat, String title, String pay, bool split, int d, [int? wallet]) => Txn(
      id: id,
      userId: who.id,
      userName: who.name,
      type: type,
      amount: amount,
      category: cat,
      title: title,
      paymentMethod: pay,
      isSplit: split,
      occurredOn: day(d),
      walletId: wallet,
    );
    // Our Maya (shared), Alex's GCash and BPI credit card, Sam's BDO debit (balance
    // private), and each partner's built-in Cash wallet.
    _wallets.addAll([
      const Wallet(id: 1, name: 'Our Maya', kind: 'ewallet', provider: 'maya'),
      Wallet(id: 2, name: 'GCash', kind: 'ewallet', provider: 'gcash', ownerId: _user.id, ownerName: _user.name),
      Wallet(id: 3, name: 'BPI Credit', kind: 'credit', provider: 'bpi', ownerId: _user.id, ownerName: _user.name, last4: '4821'),
      Wallet(id: 4, name: 'BDO Debit', kind: 'debit', provider: 'bdo', ownerId: _sam.id, ownerName: _sam.name, last4: '1029'),
      Wallet(id: 5, name: 'Cash', kind: 'cash', provider: 'cash', ownerId: _user.id, ownerName: _user.name, builtin: true),
      Wallet(id: 6, name: 'Cash', kind: 'cash', provider: 'cash', ownerId: _sam.id, ownerName: _sam.name, builtin: true),
    ]);
    _openings.addAll({1: 3000, 2: 6630, 3: 0, 4: 22800, 5: 1500, 6: 800});
    _txns.addAll([
      t(1, _user, 'income', 45000, 'income', 'Salary', 'bank', false, 1),
      t(2, _user, 'expense', 3800, 'food', 'Weekly groceries', 'card', true, 3, 3),
      t(3, _sam, 'expense', 3600, 'bills', 'Internet & water', 'gcash', true, 5),
      t(4, _sam, 'expense', 2400, 'transport', 'Fuel', 'cash', false, 6),
      t(5, _user, 'expense', 2500, 'shopping', 'Home essentials', 'card', false, 7, 3),
      t(6, _sam, 'expense', 1800, 'entertainment', 'Date Night', 'card', true, 8, 4),
      t(7, _user, 'expense', 2430, 'bills', 'Electricity Bill', 'gcash', true, 9, 2),
      t(8, _sam, 'expense', 1250, 'food', 'Groceries', 'cash', false, 10),
      // Sam's share into Our Maya.
      Txn(
        id: 9,
        userId: _sam.id,
        userName: _sam.name,
        type: 'move',
        amount: 3000,
        category: 'others',
        title: 'Our share',
        paymentMethod: 'card',
        isSplit: false,
        occurredOn: day(4),
        walletId: 4,
        toWalletId: 1,
      ),
    ]);

    _goals.addAll([
      Goal(
        id: 1,
        name: 'Japan Trip',
        subtitle: 'Travel & Experience',
        icon: 'travel',
        target: 80000,
        saved: 12000,
        targetDate: DateTime(m.year, m.month + 7),
        contributorIds: const [1, 2],
      ),
      Goal(
        id: 2,
        name: 'Emergency Fund',
        subtitle: 'Safety & Security',
        icon: 'shield',
        target: 50000,
        saved: 15000,
        targetDate: DateTime(m.year, m.month + 7),
        contributorIds: const [1, 2],
      ),
      const Goal(
        id: 3,
        name: 'New Home',
        subtitle: 'Home',
        icon: 'home',
        target: 2000000,
        saved: 160000,
        targetDate: null,
        contributorIds: [1],
      ),
    ]);

    _moods.addAll([
      Mood(
        id: 1,
        userId: 1,
        userName: 'Alex',
        mood: 'calm',
        note: "Feeling good about our progress! Let's keep it up!",
        isPrivate: false,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      Mood(
        id: 2,
        userId: 2,
        userName: 'Sam',
        mood: 'happy',
        note: 'Date night and a productive budget talk. Feeling grateful.',
        isPrivate: false,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      for (var i = 1; i <= 12; i++)
        Mood(
          id: 10 + i,
          userId: i.isEven ? 1 : 2,
          userName: i.isEven ? 'Alex' : 'Sam',
          mood: const ['happy', 'calm', 'tired', 'happy', 'anxious', 'calm'][i % 6],
          note: '',
          isPrivate: false,
          createdAt: now.subtract(Duration(days: i)),
        ),
    ]);

    _plans.addAll([
      Plan(
        id: 1,
        kind: 'date',
        title: 'Date Night',
        notes: 'Dinner by the bay',
        scheduledAt: DateTime(now.year, now.month, now.day + 2, 19),
        goal: null,
      ),
      Plan(id: 2, kind: 'life', title: 'Japan Trip', notes: '', scheduledAt: DateTime(m.year, m.month + 7, 10), goal: _goals[0]),
      Plan(id: 3, kind: 'life', title: 'New Home', notes: '', scheduledAt: null, goal: _goals[2]),
      Plan(id: 4, kind: 'date', title: 'Anniversary', notes: '', scheduledAt: DateTime(now.year, now.month + 1, 23, 18), goal: null),
    ]);

    _answers[2] = const [
      TalkAnswer(userId: 1, userName: 'Alex', answer: 'Sometimes I worry we are not saving enough for emergencies.'),
      TalkAnswer(userId: 2, userName: 'Sam', answer: 'Our food delivery spending creeping up.'),
    ];
    _answers[3] = const [
      TalkAnswer(userId: 1, userName: 'Alex', answer: 'Cooking at home together on Sunday.'),
      TalkAnswer(userId: 2, userName: 'Sam', answer: 'The picnic. Cheap and so fun!'),
    ];
    _pastTalkDates[2] = now.subtract(const Duration(days: 7));
    _pastTalkDates[3] = now.subtract(const Duration(days: 14));
  }

  Couple _demoCouple(List<Member> members, [String theme = 'sage']) => Couple(id: 1, inviteCode: 'NEST01', theme: theme, members: members);

  Couple get _requireCouple => _couple ?? (throw Exception('Create or join a nest first.'));

  @override
  Future<Me?> restoreSession() => _delay(() => _me);

  /// Demo recovery key for Alex & Sam's nest; any key starting "DEMO" works.
  static const demoKey = 'DEMO-ALEX-0000-NEST';

  @override
  Future<({Me me, String recoveryKey})> start(String name, OnboardingProfile profile) => _delay(() {
    if (name.trim().isEmpty) throw Exception('Tell us what to call you.');
    _user = Member(id: 1, name: name.trim());
    _profile = profile;
    _couple = null;
    final me = _me = Me(user: _user, partnerName: profile.partnerName);
    return (me: me, recoveryKey: 'K7QM-2WXP-9DTR-H4NB');
  });

  @override
  Future<Me> recover(String recoveryKey) => _delay(() {
    if (!recoveryKey.trim().toUpperCase().startsWith('DEMO')) throw Exception("That recovery key doesn't match any nest.");
    _user = const Member(id: 1, name: 'Alex');
    _couple ??= _demoCouple([_user, _sam]);
    return _me = Me(user: _user, couple: _couple);
  });

  @override
  Future<Me> redeemRelink(String code) => code.replaceAll(RegExp('[^A-Za-z0-9]'), '').length != 8
      ? Future.delayed(latency, () => throw Exception('That code has expired or was already used. Ask your partner for a new one.'))
      : recover(demoKey).then((me) {
          // Adds a phone; the old one stays signed in.
          _devices = [
            Device(id: _nextId++, relinked: true, current: true, createdAt: DateTime.now(), lastUsedAt: DateTime.now()),
            for (final d in _devices)
              Device(id: d.id, relinked: d.relinked, current: false, createdAt: d.createdAt, lastUsedAt: d.lastUsedAt),
          ];
          return me;
        });

  /// This phone, plus the old one from before a re-link.
  List<Device> _devices = [Device(id: 900, relinked: false, current: true, createdAt: DateTime(2026, 3, 2), lastUsedAt: DateTime.now())];

  @override
  Future<List<Device>> devices() => _delay(() => List.of(_devices));

  @override
  Future<void> removeDevice(int id) => _delay(() {
    if (!_devices.any((d) => d.id == id)) throw Exception('That phone is already signed out.');
    if (_devices.firstWhere((d) => d.id == id).current) _me = null;
    _devices.removeWhere((d) => d.id == id);
  });

  @override
  Future<({String code, DateTime expiresAt, String forName})> relinkCode() => _delay(() {
    final partner = _couple?.members.where((m) => m.id != _user.id).firstOrNull;
    if (partner == null) throw Exception('Your partner needs to join before you can re-link their phone.');
    return (code: 'QX4M7KDP', expiresAt: DateTime.now().add(const Duration(minutes: 10)), forName: partner.name);
  });

  @override
  Future<Me> uploadAvatar(Uint8List bytes, String filename) => _delay(() {
    _avatars[_user.id] = bytes;
    return _setUser(Member(id: _user.id, name: _user.name, avatarVersion: DateTime.now().millisecondsSinceEpoch));
  });

  @override
  Future<Me> removeAvatar() => _delay(() {
    _avatars.remove(_user.id);
    return _setUser(Member(id: _user.id, name: _user.name));
  });

  @override
  Future<Uint8List?> avatar(int userId) => _delay(() => _avatars[userId]);

  /// Swaps in the updated signed-in member, in the couple too.
  Me _setUser(Member user) {
    _user = user;
    final couple = _couple;
    if (couple != null) _couple = couple.copyWith(members: [for (final m in couple.members) m.id == user.id ? user : m]);
    return _me = Me(user: _user, couple: _couple, partnerName: _me?.partnerName);
  }

  @override
  Future<String> newRecoveryKey() => _delay(() => 'P3RN-8VBC-M2TQ-W6HJ');

  @override
  Future<void> logout() => _delay(() => _me = null);

  @override
  Future<Me> createNest(String theme) => _delay(() {
    _couple = Couple(id: 1, inviteCode: 'NEST01', theme: theme, members: [_user], stage: _profile.stage);
    _applyStarterGoals();
    _ensureCash();
    final budget = _profile.monthlyBudget ?? 0;
    if (budget > 0) _budgets[monthKey(DateTime.now())] = (budget, const {});
    return _me = Me(user: _user, couple: _couple, partnerName: _profile.partnerName);
  });

  /// Your built-in Cash wallet, as the server adds it when you create or join a nest.
  void _ensureCash() {
    if (_wallets.any((w) => w.builtin && w.ownerId == _user.id)) return;
    final w = Wallet(id: _nextId++, name: 'Cash', kind: 'cash', provider: 'cash', ownerId: _user.id, ownerName: _user.name, builtin: true);
    _wallets.add(w);
    _openings[w.id] = 0;
  }

  /// Onboarding goal picks become savings goals the nest doesn't have yet.
  void _applyStarterGoals() {
    final have = {for (final g in _goals) g.name.toLowerCase()};
    for (final key in [..._profile.financialGoals, ..._profile.familyGoals]) {
      final o = goalOption(key);
      if (o == null || !have.add(o.goalName.toLowerCase())) continue;
      _goals.add(
        Goal(
          id: _nextId++,
          name: o.goalName,
          subtitle: '',
          icon: o.icon,
          target: o.target,
          saved: 0,
          targetDate: null,
          contributorIds: const [],
        ),
      );
    }
  }

  @override
  Future<Me> joinNest(String code) => _delay(() {
    if (code.trim().length != 6) throw Exception("We couldn't find a nest with that code.");
    _couple = _demoCouple([_sam, _user]);
    _ensureCash();
    return _me = Me(user: _user, couple: _couple);
  });

  @override
  Future<void> updateTheme(String theme) => _delay(() {
    _couple = _requireCouple.copyWith(theme: theme);
    _me = Me(user: _user, couple: _couple);
  });

  @override
  Future<Dashboard> dashboard() async {
    final now = DateTime.now();
    final budget = await this.budget(now);
    final recent = await transactions();
    final spending = <String, double>{};
    for (final t in recent) {
      if (t.isExpense && t.occurredOn.year == now.year && t.occurredOn.month == now.month) {
        spending[t.category] = (spending[t.category] ?? 0) + t.amount;
      }
    }
    final sorted = Map.fromEntries(spending.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    final soon = DateTime(now.year, now.month, now.day + 14);
    final bills = await this.bills();
    return Dashboard(
      budget: budget,
      recent: recent.take(5).toList(),
      spending: sorted,
      lastMonthSpent: _txns.isEmpty ? 0 : 15900,
      savedThisMonth: math.max(
        0,
        _txns
            .where((t) => (t.isTransfer || t.isRelease) && t.occurredOn.year == now.year && t.occurredOn.month == now.month)
            .fold(0.0, (a, t) => a + (t.isRelease ? -t.amount : t.amount)),
      ),
      upcomingBills: bills.where((b) => !b.nextDueOn.isAfter(soon)).take(5).toList(),
      paydays: await paydays(),
      wallets: await wallets(),
    );
  }

  @override
  Future<List<Bill>> bills() => _delay(() => [..._bills]..sort((a, b) => a.nextDueOn.compareTo(b.nextDueOn)));

  Bill _bill(int id, BillDraft d, String userName) => Bill(
    id: id,
    title: d.title,
    amount: d.amount,
    category: d.category,
    frequency: d.frequency,
    nextDueOn: d.nextDueOn,
    isSplit: d.isSplit,
    userName: userName,
    walletId: _checkWallet(d.walletId, _user.id),
  );

  int _billIndex(int id) {
    final i = _bills.indexWhere((b) => b.id == id);
    if (i < 0) throw Exception('That bill no longer exists.');
    return i;
  }

  @override
  Future<Bill> addBill(BillDraft d) => _delay(() {
    final b = _bill(_nextId++, d, _user.name);
    _bills.add(b);
    return b;
  });

  @override
  Future<Bill> updateBill(int id, BillDraft d) => _delay(() {
    final i = _billIndex(id);
    return _bills[i] = _bill(id, d, _bills[i].userName);
  });

  @override
  Future<void> deleteBill(int id) => _delay(() => _bills.removeWhere((b) => b.id == id));

  @override
  Future<SplitBalance> balance() => _delay(() {
    final members = [...?_couple?.members]..sort((a, b) => a.id.compareTo(b.id));
    if (members.length < 2) return const SplitBalance();
    final now = DateTime.now();
    double sum(Iterable<double> xs) => xs.fold(0, (a, b) => a + b);
    final shared = {for (final w in _wallets.where((w) => w.isShared)) w.id};
    bool thisMonth(Txn t) => t.occurredOn.year == now.year && t.occurredOn.month == now.month;
    // Spending from a shared wallet isn't owed by either of you.
    double splitPaid(Member m) =>
        sum(_txns.where((t) => t.isExpense && t.isSplit && t.userId == m.id && !shared.contains(t.walletId)).map((t) => t.amount));
    double toppedUp(Member m) => sum(
      _txns
          .where((t) => t.isMove && t.userId == m.id && shared.contains(t.toWalletId) && !shared.contains(t.walletId) && thisMonth(t))
          .map((t) => t.amount),
    );
    double settledOut(Member m) => sum(_settlements.where((s) => s.fromId == m.id).map((s) => s.amount));
    final [a, b] = members;
    // Positive: b owes a.
    final net = (((splitPaid(a) - splitPaid(b)) / 2 - settledOut(b) + settledOut(a)) * 100).roundToDouble() / 100;
    return SplitBalance(
      owes: net.abs() < 0.01 ? null : Owes(from: net > 0 ? b : a, to: net > 0 ? a : b, amount: net.abs()),
      members: [
        for (final m in members)
          MemberPaid(
            id: m.id,
            name: m.name,
            splitPaid: splitPaid(m),
            paidThisMonth: sum(
              _txns
                  .where((t) => t.isExpense && t.userId == m.id && t.occurredOn.year == now.year && t.occurredOn.month == now.month)
                  .map((t) => t.amount),
            ),
            toppedUpThisMonth: toppedUp(m),
          ),
      ],
      settlements: [..._settlements.reversed.take(10)],
      sharedSpentThisMonth: sum(_txns.where((t) => t.isExpense && shared.contains(t.walletId) && thisMonth(t)).map((t) => t.amount)),
    );
  });

  @override
  Future<Settlement> settleUp({required double amount, required int fromUserId, int? fromWalletId, int? toWalletId}) => _delay(() {
    final members = _couple?.members ?? const <Member>[];
    if (members.length < 2) throw Exception('Your partner needs to join before you can settle up.');
    final from = members.firstWhere((m) => m.id == fromUserId);
    final to = members.firstWhere((m) => m.id != fromUserId);
    // Only your own side: your partner's wallets are theirs to track.
    Wallet? own(int? id, Member m) {
      if (id == null) return null;
      if (m.id != _user.id) throw Exception('Only your partner can pick their wallet.');
      final w = _wallets.where((w) => w.id == id).firstOrNull;
      if (w == null || w.ownerId != m.id) throw Exception('Pick one of your own wallets.');
      return w;
    }

    final fromWallet = own(fromWalletId, from);
    final toWallet = own(toWalletId, to);
    final now = DateTime.now();
    final s = Settlement(
      id: _nextId++,
      fromId: from.id,
      fromName: from.name,
      toId: to.id,
      toName: to.name,
      amount: amount,
      settledOn: DateTime(now.year, now.month, now.day),
      fromWalletId: fromWallet?.id,
      fromWalletName: fromWallet?.name,
      toWalletId: toWallet?.id,
      toWalletName: toWallet?.name,
    );
    _settlements.add(s);
    return s;
  });

  @override
  Future<void> deleteSettlement(int id) => _delay(() {
    final s = _settlements.where((s) => s.id == id).firstOrNull;
    if (s != null) _ensureNotPartners([s.fromWalletId, s.toWalletId]);
    _settlements.removeWhere((s) => s.id == id);
  });

  @override
  Future<Settlement> setSettlementWallet(int id, int? walletId) => _delay(() {
    final i = _settlements.indexWhere((s) => s.id == id);
    if (i < 0) throw Exception('That settle-up is gone.');
    final s = _settlements[i];
    final w = walletId == null ? null : _wallets.where((w) => w.id == walletId).firstOrNull;
    if (walletId != null && (w == null || w.isShared || w.ownerId != _user.id)) throw Exception('Pick one of your own wallets.');
    final paid = s.fromId == _user.id;
    return _settlements[i] = Settlement(
      id: s.id,
      fromId: s.fromId,
      fromName: s.fromName,
      toId: s.toId,
      toName: s.toName,
      amount: s.amount,
      settledOn: s.settledOn,
      fromWalletId: paid ? w?.id : s.fromWalletId,
      fromWalletName: paid ? w?.name : s.fromWalletName,
      toWalletId: paid ? s.toWalletId : w?.id,
      toWalletName: paid ? s.toWalletName : w?.name,
    );
  });

  @override
  Future<({Bill bill, int transactionId})> payBill(int id) async {
    final b = _bills[_billIndex(id)];
    final now = DateTime.now();
    final txn = await addTransaction(
      TxnDraft(
        type: 'expense',
        amount: b.amount,
        category: b.category,
        title: b.title,
        paymentMethod: 'cash',
        isSplit: b.isSplit,
        occurredOn: DateTime(now.year, now.month, now.day),
        walletId: _quietWallet(b.walletId, _user.id),
      ),
    );
    final due = b.nextDueOn;
    final next = b.isWeekly
        ? due.add(const Duration(days: 7))
        : DateTime(due.year, due.month + 1, due.day.clamp(1, DateTime(due.year, due.month + 2, 0).day));
    final paid = _withDue(b, next);
    _bills[_billIndex(id)] = paid;
    return (bill: paid, transactionId: txn.id);
  }

  @override
  Future<Bill> unpayBill(int id, {required int transactionId, required DateTime previousDue}) => _delay(() {
    _ensureNotPartners([_txns.where((t) => t.id == transactionId).firstOrNull?.walletId]);
    _txns.removeWhere((t) => t.id == transactionId);
    final i = _billIndex(id);
    return _bills[i] = _withDue(_bills[i], previousDue);
  });

  Bill _withDue(Bill b, DateTime due) => Bill(
    id: b.id,
    title: b.title,
    amount: b.amount,
    category: b.category,
    frequency: b.frequency,
    nextDueOn: due,
    isSplit: b.isSplit,
    userName: b.userName,
    walletId: b.walletId,
  );

  /// Money in minus money out per wallet, like the server's Wallet::flows.
  Map<int, double> _flows() {
    final flows = <int, double>{};
    for (final t in _txns) {
      if (t.walletId != null) {
        flows[t.walletId!] = (flows[t.walletId!] ?? 0) + (t.isIncome || t.isRelease ? t.amount : -t.amount);
      }
      if (t.isMove && t.toWalletId != null) flows[t.toWalletId!] = (flows[t.toWalletId!] ?? 0) + t.amount;
    }
    for (final s in _settlements) {
      if (s.fromWalletId != null) flows[s.fromWalletId!] = (flows[s.fromWalletId!] ?? 0) - s.amount;
      if (s.toWalletId != null) flows[s.toWalletId!] = (flows[s.toWalletId!] ?? 0) + s.amount;
    }
    return flows;
  }

  Wallet _present(Wallet w, [Map<int, double>? flows]) {
    final visible = w.usableBy(_user.id) || w.showBalanceToPartner;
    if (!visible) return w;
    final balance = (_openings[w.id] ?? 0) + ((flows ?? _flows())[w.id] ?? 0);
    return w.copyWith(balance: (balance * 100).roundToDouble() / 100);
  }

  Wallet _rawWallet(int id) => _wallets.firstWhere((w) => w.id == id, orElse: () => throw Exception('That wallet is gone.'));

  /// A shared wallet or one of [userId]'s own, as the server checks it.
  int? _checkWallet(int? id, int userId) {
    if (id == null) return null;
    final w = _wallets.where((w) => w.id == id).firstOrNull;
    if (w == null || !w.usableBy(userId)) throw Exception('Pick one of your wallets or a shared one.');
    return id;
  }

  /// [_checkWallet] for the payer, and you must be able to use it too: a
  /// partner's personal wallet is theirs to log, as the server checks it.
  int? _checkLogWallet(int? id, int payerId) {
    final checked = _checkWallet(id, payerId);
    if (checked != null && !_rawWallet(checked).usableBy(_user.id)) {
      throw Exception('Pick a shared wallet, or let them log it from their own.');
    }
    return checked;
  }

  /// Only a wallet's owner changes entries on it.
  void _ensureNotPartners(List<int?> ids) {
    for (final id in ids) {
      final w = _wallets.where((w) => w.id == id).firstOrNull;
      if (w != null && !w.isShared && w.ownerId != _user.id) {
        throw Exception('Only ${w.ownerName} can change entries on their own wallets.');
      }
    }
  }

  /// A remembered wallet if [userId] can still use it, else none.
  int? _quietWallet(int? id, int userId) {
    final w = _wallets.where((w) => w.id == id).firstOrNull;
    return w != null && w.usableBy(userId) ? w.id : null;
  }

  String _walletPaymentMethod(int id) {
    final w = _rawWallet(id);
    if (w.provider == 'gcash' || w.provider == 'maya') return w.provider;
    return switch (w.kind) {
      'cash' => 'cash',
      'debit' || 'credit' => 'card',
      _ => 'bank',
    };
  }

  int _myWalletIndex(int id) {
    final i = _wallets.indexWhere((w) => w.id == id);
    if (i < 0) throw Exception('That wallet is gone.');
    final w = _wallets[i];
    if (!w.usableBy(_user.id)) throw Exception("Only ${w.ownerName} can change ${w.ownerName}'s wallet.");
    return i;
  }

  Wallet _walletFrom(int id, WalletDraft d, {required int? ownerId, required String ownerName}) => Wallet(
    id: id,
    name: d.name,
    kind: d.kind,
    provider: d.provider,
    ownerId: ownerId,
    ownerName: ownerName,
    last4: d.last4,
    showBalanceToPartner: d.showBalanceToPartner,
  );

  @override
  Future<({Txn transaction, List<Wallet> wallets})> moveMoney({
    required int fromWalletId,
    required int toWalletId,
    required double amount,
    String? note,
    double? fee,
  }) async {
    if (fromWalletId == toWalletId) throw Exception('Pick two different wallets.');
    final from = _rawWallet(_checkWallet(fromWalletId, _user.id)!);
    final to = _rawWallet(_checkWallet(toWalletId, _user.id)!);
    final now = DateTime.now();
    final move = Txn(
      id: _nextId++,
      userId: _user.id,
      userName: _user.name,
      type: 'move',
      amount: amount,
      category: 'others',
      title: (note ?? '').trim().isEmpty ? '${from.name} → ${to.name}' : note!.trim(),
      paymentMethod: _walletPaymentMethod(from.id),
      isSplit: false,
      occurredOn: DateTime(now.year, now.month, now.day),
      walletId: from.id,
      toWalletId: to.id,
    );
    _txns.add(move);
    if ((fee ?? 0) > 0) {
      _txns.add(
        Txn(
          id: _nextId++,
          userId: _user.id,
          userName: _user.name,
          type: 'expense',
          amount: fee!,
          category: 'others',
          title: 'Fee · ${from.name} → ${to.name}',
          paymentMethod: move.paymentMethod,
          isSplit: false,
          occurredOn: move.occurredOn,
          walletId: from.id,
          moveId: move.id,
        ),
      );
    }
    return (transaction: move, wallets: await wallets());
  }

  @override
  Future<List<Wallet>> wallets() => _delay(() {
    final flows = _flows();
    final sorted = [..._wallets]..sort((a, b) => a.isShared == b.isShared ? a.id.compareTo(b.id) : (a.isShared ? -1 : 1));
    return [for (final w in sorted) _present(w, flows)];
  });

  @override
  Future<Wallet> addWallet(WalletDraft d) => _delay(() {
    final w = _walletFrom(_nextId++, d, ownerId: d.isShared ? null : _user.id, ownerName: d.isShared ? '' : _user.name);
    _wallets.add(w);
    _openings[w.id] = d.balance ?? 0;
    return _present(w);
  });

  @override
  Future<Wallet> updateWallet(int id, WalletDraft d) => _delay(() {
    final i = _myWalletIndex(id);
    final old = _wallets[i];
    final next = _walletFrom(id, d, ownerId: old.ownerId, ownerName: old.ownerName);
    return _present(
      _wallets[i] = old.builtin
          ? Wallet(
              id: id,
              name: next.name,
              kind: old.kind,
              provider: old.provider,
              ownerId: old.ownerId,
              ownerName: old.ownerName,
              showBalanceToPartner: next.showBalanceToPartner,
              builtin: true,
            )
          : next,
    );
  });

  @override
  Future<void> archiveWallet(int id) => _delay(() {
    final i = _myWalletIndex(id);
    if (_wallets[i].builtin) {
      throw Exception("${_wallets[i].name} is built in. You can rename it or correct its balance, but not remove it.");
    }
    _wallets.removeAt(i);
  });

  @override
  Future<Wallet> setWalletBalance(int id, double balance) => _delay(() {
    final w = _wallets[_myWalletIndex(id)];
    _openings[id] = balance - (_flows()[id] ?? 0);
    return _present(w);
  });

  @override
  Future<List<Payday>> paydays() => _delay(() => [..._paydays]..sort((a, b) => a.nextOn.compareTo(b.nextOn)));

  /// One of my paydays; a partner's can't be changed or logged.
  int _myPaydayIndex(int id) {
    final i = _paydays.indexWhere((d) => d.id == id);
    if (i < 0) throw Exception('That payday is gone.');
    final d = _paydays[i];
    if (d.userId != _user.id) throw Exception("Only ${d.userName} can change ${d.userName}'s payday.");
    return i;
  }

  Payday _payday(int id, PaydayDraft d, {DateTime? nextOn}) {
    final now = DateTime.now();
    final days = isByDay(d.frequency) ? ([...d.days]..sort()) : const <int>[];
    return Payday(
      id: id,
      userId: _user.id,
      userName: _user.name,
      title: d.title,
      amount: d.amount,
      frequency: d.frequency,
      days: days,
      nextOn: nextOn ?? (isByDay(d.frequency) ? firstPaydayOnOrAfter(days, now) : d.nextOn!),
      isSplit: d.isSplit,
      walletId: _checkWallet(d.walletId, _user.id),
    );
  }

  Payday _withNext(Payday d, DateTime nextOn) => Payday(
    id: d.id,
    userId: d.userId,
    userName: d.userName,
    title: d.title,
    amount: d.amount,
    frequency: d.frequency,
    days: d.days,
    nextOn: nextOn,
    isSplit: d.isSplit,
    walletId: d.walletId,
  );

  @override
  Future<Payday> addPayday(PaydayDraft d) => _delay(() {
    final payday = _payday(_nextId++, d);
    _paydays.add(payday);
    return payday;
  });

  @override
  Future<Payday> updatePayday(int id, PaydayDraft d) => _delay(() {
    final i = _myPaydayIndex(id);
    return _paydays[i] = _payday(id, d);
  });

  @override
  Future<void> deletePayday(int id) => _delay(() => _paydays.removeAt(_myPaydayIndex(id)));

  @override
  Future<({Payday payday, int transactionId})> receivePayday(int id, {double? amount}) async {
    final d = _paydays[_myPaydayIndex(id)];
    final now = DateTime.now();
    final txn = await addTransaction(
      TxnDraft(
        type: 'income',
        amount: amount ?? d.amount,
        category: 'income',
        title: d.title,
        paymentMethod: 'bank',
        isSplit: d.isSplit,
        occurredOn: DateTime(now.year, now.month, now.day),
        walletId: _quietWallet(d.walletId, d.userId),
      ),
    );
    final moved = _withNext(d, nextPayday(d.frequency, d.nextOn, d.days));
    _paydays[_myPaydayIndex(id)] = moved;
    return (payday: moved, transactionId: txn.id);
  }

  @override
  Future<Payday> unreceivePayday(int id, {required int transactionId, required DateTime previousNext}) => _delay(() {
    _txns.removeWhere((t) => t.id == transactionId);
    final i = _myPaydayIndex(id);
    return _paydays[i] = _withNext(_paydays[i], previousNext);
  });

  @override
  Future<List<FeedItem>> feed() => _delay(() {
    final partner = _couple?.members.where((m) => m.id != _user.id).firstOrNull;
    if (partner == null) return const <FeedItem>[];
    final items = <FeedItem>[
      for (final t in _txns.where((t) => t.userId == partner.id && !t.isTransfer))
        FeedItem(
          type: t.isExpense ? 'expense' : 'income',
          userName: partner.name,
          title: t.isExpense ? '${partner.name} added an expense' : '${partner.name} added income',
          subtitle: t.title,
          amount: t.amount,
          at: t.occurredOn.add(const Duration(hours: 12)),
        ),
      for (final s in _settlements.where((s) => s.fromId == partner.id))
        FeedItem(
          type: 'settle',
          userName: partner.name,
          title: '${partner.name} settled up with you',
          amount: s.amount,
          at: DateTime.now(),
        ),
      for (final m in _moods.where((m) => m.userId == partner.id && !m.isPrivate))
        FeedItem(
          type: 'mood',
          userName: partner.name,
          title: '${partner.name} is feeling ${m.mood}',
          subtitle: m.note.isEmpty ? null : m.note,
          at: m.createdAt,
        ),
      FeedItem(
        type: 'goal',
        userName: partner.name,
        title: '${partner.name} saved toward Japan Trip',
        amount: 5000,
        at: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return items.take(30).toList();
  });

  @override
  Future<List<Txn>> transactions({DateTime? month, DateTime? from, DateTime? to, String query = ''}) => _delay(() {
    final q = query.trim().toLowerCase();
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    return _txns
        .where((t) => month == null || (t.occurredOn.year == month.year && t.occurredOn.month == month.month))
        .where((t) => from == null || to == null || (!day(t.occurredOn).isBefore(day(from)) && !day(t.occurredOn).isAfter(day(to))))
        .where((t) => q.isEmpty || t.title.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => b.occurredOn.compareTo(a.occurredOn) != 0 ? b.occurredOn.compareTo(a.occurredOn) : b.id.compareTo(a.id));
  });

  /// Who paid [d]: the member it names, else whoever is logging it.
  Member _payer(TxnDraft d, Member fallback) =>
      (_couple?.members ?? const <Member>[]).where((m) => m.id == d.paidBy).firstOrNull ?? fallback;

  @override
  Future<Txn> addTransaction(TxnDraft d) => _delay(() {
    final payer = _payer(d, _user);
    final t = Txn(
      id: _nextId++,
      userId: payer.id,
      userName: payer.name,
      type: d.type,
      amount: d.amount,
      category: d.category,
      title: d.title,
      paymentMethod: d.walletId == null ? d.paymentMethod : _walletPaymentMethod(d.walletId!),
      isSplit: d.isSplit,
      occurredOn: d.occurredOn,
      walletId: _checkLogWallet(d.walletId, payer.id),
    );
    _txns.add(t);
    return t;
  });

  @override
  Future<Txn> updateTransaction(int id, TxnDraft d) => _delay(() {
    final i = _txns.indexWhere((t) => t.id == id);
    if (i < 0) throw Exception('That transaction no longer exists.');
    final old = _txns[i];
    _ensureNotPartners([old.walletId, old.toWalletId]);
    final payer = _payer(d, Member(id: old.userId, name: old.userName));
    return _txns[i] = Txn(
      id: id,
      userId: payer.id,
      userName: payer.name,
      type: d.type,
      amount: d.amount,
      category: d.category,
      title: d.title,
      paymentMethod: d.walletId == null ? d.paymentMethod : _walletPaymentMethod(d.walletId!),
      isSplit: d.isSplit,
      occurredOn: d.occurredOn,
      goalId: old.goalId,
      walletId: _checkLogWallet(d.walletId, payer.id),
    );
  });

  @override
  Future<void> deleteTransaction(int id) => _delay(() {
    final i = _txns.indexWhere((t) => t.id == id);
    if (i < 0) return;
    if (_txns[i].isRelease) throw Exception('Restore the goal instead.');
    _ensureNotPartners([_txns[i].walletId, _txns[i].toWalletId]);
    final t = _txns.removeAt(i);
    if (t.isTransfer) _addToGoal(t.goalId, -t.amount);
    // A move's fee goes with it.
    _txns.removeWhere((f) => f.moveId == t.id);
  });

  @override
  Future<BudgetSummary> budget(DateTime month) => _delay(() {
    final m = monthStart(month);
    final (total, limits) = _budgets[monthKey(m)] ?? (0.0, const <String, double>{});
    final spentBy = <String, double>{};
    for (final t in _txns) {
      if (t.isExpense && t.occurredOn.year == m.year && t.occurredOn.month == m.month) {
        spentBy[t.category] = (spentBy[t.category] ?? 0) + t.amount;
      }
    }
    return BudgetSummary(
      month: m,
      total: total,
      spent: spentBy.values.fold(0, (a, b) => a + b),
      lines: [for (final e in limits.entries) BudgetLine(category: e.key, limit: e.value, spent: spentBy[e.key] ?? 0)],
    );
  });

  @override
  Future<BudgetSummary> saveBudget(DateTime month, double total, Map<String, double> limits) {
    _budgets[monthKey(month)] = (total, Map.of(limits));
    return budget(month);
  }

  @override
  // Active goals first; cancelled ones sink to the bottom.
  Future<List<Goal>> goals() => _delay(() => [..._goals.reversed.where((g) => !g.cancelled), ..._goals.reversed.where((g) => g.cancelled)]);

  @override
  Future<Goal> addGoal({required String name, String? subtitle, required String icon, required double target, DateTime? targetDate}) =>
      _delay(() {
        final g = Goal(
          id: _nextId++,
          name: name,
          subtitle: subtitle ?? '',
          icon: icon,
          target: target,
          saved: 0,
          targetDate: targetDate,
          contributorIds: const [],
        );
        _goals.add(g);
        return g;
      });

  @override
  Future<Goal> updateGoal(
    int id, {
    required String name,
    String? subtitle,
    required String icon,
    required double target,
    DateTime? targetDate,
  }) => _delay(() {
    final i = _goals.indexWhere((g) => g.id == id);
    if (i < 0) throw Exception('That goal no longer exists.');
    return _goals[i] = _goals[i].copyWith(name: name, subtitle: subtitle ?? '', icon: icon, target: target, targetDate: targetDate);
  });

  @override
  Future<({Goal goal, int? transferId})> contribute(int goalId, double amount, {int? walletId}) => _delay(() {
    if (_goals.where((g) => g.id == goalId && g.cancelled).isNotEmpty) throw Exception('Restore this goal before adding to it.');
    final goal = _addToGoal(goalId, amount);
    if (goal == null) throw Exception('That goal no longer exists.');
    final now = DateTime.now();
    final transfer = Txn(
      id: _nextId++,
      userId: _user.id,
      userName: _user.name,
      type: 'transfer',
      amount: amount,
      category: 'savings',
      title: 'Transfer to ${goal.name}',
      paymentMethod: 'bank',
      isSplit: false,
      occurredOn: DateTime(now.year, now.month, now.day),
      walletId: _checkWallet(walletId, _user.id),
      goalId: goalId,
    );
    _txns.add(transfer);
    return (goal: goal, transferId: transfer.id);
  });

  /// Adds [amount] (negative to take back) to a goal's savings.
  Goal? _addToGoal(int? goalId, double amount) {
    final i = _goals.indexWhere((g) => g.id == goalId);
    if (i < 0) return null;
    final g = _goals[i];
    return _goals[i] = g.copyWith(
      saved: (g.saved + amount).clamp(0, double.infinity),
      contributorIds: amount > 0 ? {...g.contributorIds, _user.id}.toList() : g.contributorIds,
    );
  }

  @override
  Future<Goal> cancelGoal(int id) => _delay(() {
    final i = _goals.indexWhere((g) => g.id == id);
    if (i < 0) throw Exception('That goal no longer exists.');
    final g = _goals[i];
    if (g.cancelled) throw Exception('This goal is already cancelled.');
    final now = DateTime.now();
    if (g.saved > 0) {
      _txns.add(
        Txn(
          id: _nextId++,
          userId: _user.id,
          userName: _user.name,
          type: 'release',
          amount: g.saved,
          category: 'savings',
          title: 'Released from ${g.name}',
          paymentMethod: 'bank',
          isSplit: false,
          occurredOn: DateTime(now.year, now.month, now.day),
          goalId: id,
        ),
      );
    }
    return _goals[i] = g.copyWith(cancelledAt: now);
  });

  @override
  Future<Goal> restoreGoal(int id) => _delay(() {
    final i = _goals.indexWhere((g) => g.id == id);
    if (i < 0) throw Exception('That goal no longer exists.');
    _txns.removeWhere((t) => t.isRelease && t.goalId == id);
    return _goals[i] = _goals[i].copyWith(restore: true);
  });

  @override
  Future<List<Mood>> moods() =>
      _delay(() => _moods.where((m) => m.userId == _user.id || !m.isPrivate).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  @override
  Future<Mood> addMood({required String mood, String? note, required bool isPrivate}) => _delay(() {
    final m = Mood(
      id: _nextId++,
      userId: _user.id,
      userName: _user.name,
      mood: mood,
      note: note ?? '',
      isPrivate: isPrivate,
      createdAt: DateTime.now(),
    );
    _moods.add(m);
    return m;
  });

  @override
  Future<TalkState> currentTalk() => _delay(() {
    _requireCouple;
    final answers = _answers[1] ?? const [];
    final mine = answers.any((a) => a.userId == _user.id);
    return TalkState(prompt: _prompts.first, answered: mine, answers: mine ? answers : const []);
  });

  @override
  Future<TalkState> answerTalk(String answer) {
    final partnerAnswer = TalkAnswer(userId: _sam.id, userName: _sam.name, answer: 'A weekend trip to Baguio!');
    _answers[1] = [TalkAnswer(userId: _user.id, userName: _user.name, answer: answer), if (_couple?.members.length == 2) partnerAnswer];
    return currentTalk();
  }

  @override
  Future<List<PastTalk>> talkHistory() => _delay(() => [for (final p in _prompts.skip(1)) _pastTalk(p, _answers[p.id] ?? const [])]);

  /// A partner's past answer stays private unless you answered too.
  PastTalk _pastTalk(Prompt p, List<TalkAnswer> answers) {
    final shared = answers.any((a) => a.userId == _user.id);
    return PastTalk(
      prompt: p,
      lastAnsweredAt: _pastTalkDates[p.id]!,
      answers: shared ? answers : const [],
      hidden: shared ? const [] : [for (final a in answers) a.userName],
    );
  }

  @override
  Future<List<Plan>> plans() => _delay(
    () => List.of(_plans)
      ..sort((a, b) {
        if (a.scheduledAt == null) return b.scheduledAt == null ? 0 : 1;
        if (b.scheduledAt == null) return -1;
        return a.scheduledAt!.compareTo(b.scheduledAt!);
      }),
  );

  @override
  Future<Plan> addPlan({required String kind, required String title, String? notes, DateTime? scheduledAt, int? goalId}) => _delay(() {
    final goal = goalId == null ? null : _goals.where((g) => g.id == goalId).firstOrNull;
    final p = Plan(id: _nextId++, kind: kind, title: title, notes: notes ?? '', scheduledAt: scheduledAt, goal: goal);
    _plans.add(p);
    return p;
  });

  @override
  Future<void> deletePlan(int id) => _delay(() => _plans.removeWhere((p) => p.id == id));
}
