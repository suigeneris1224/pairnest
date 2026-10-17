import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/core/theme/palettes.dart';
import 'package:pairnest/data/mock_repository.dart';
import 'package:pairnest/data/models.dart';

void main() {
  test('BudgetSummary parses API JSON and computes remaining', () {
    final b = BudgetSummary.fromJson({
      'month': '2025-05',
      'total': 32000,
      'spent': 18450.5,
      'lines': [
        {'category': 'food', 'limit': 8000, 'spent': 9000},
      ],
    });
    expect(b.month, DateTime(2025, 5));
    expect(b.remaining, closeTo(13549.5, 0.001));
    expect(b.lines.single.remaining, -1000);
    expect(b.lines.single.ratio, greaterThan(1));
  });

  test('Me resolves partner and couple names', () {
    final me = Me.fromJson({
      'id': 1,
      'name': 'Alex',
      'profile': {'partner_name': 'Sam'},
      'couple': {
        'id': 9,
        'invite_code': 'ABC123',
        'theme': 'ocean',
        'stage': 'married',
        'members': [
          {'id': 1, 'name': 'Alex'},
          {'id': 2, 'name': 'Sam'},
        ],
      },
    });
    expect(me.partner?.name, 'Sam');
    expect(me.coupleNames, 'Alex & Sam');
    expect(me.couple!.stage, 'married');
    expect(paletteById(me.couple!.theme).name, 'Ocean Blue');
    expect(paletteById('nope').id, 'sage');
  });

  test('mock budget only counts expenses for the month', () async {
    final repo = MockRepository(latency: Duration.zero);
    await repo.recover(MockRepository.demoKey);
    final now = DateTime.now();
    final before = await repo.budget(now);

    await repo.addTransaction(
      TxnDraft(type: 'income', amount: 999, category: 'income', title: 'Bonus', paymentMethod: 'bank', isSplit: false, occurredOn: now),
    );
    await repo.addTransaction(
      TxnDraft(type: 'expense', amount: 500, category: 'food', title: 'Snacks', paymentMethod: 'cash', isSplit: true, occurredOn: now),
    );

    final after = await repo.budget(now);
    expect(after.spent - before.spent, 500);
    expect(after.lines.firstWhere((l) => l.category == 'food').spent - before.lines.firstWhere((l) => l.category == 'food').spent, 500);
  });

  test('mock moods hide only the partner\'s private check-ins', () async {
    final repo = MockRepository(latency: Duration.zero);
    await repo.recover(MockRepository.demoKey);
    await repo.addMood(mood: 'tired', note: 'just me', isPrivate: true);
    final moods = await repo.moods();
    expect(moods.where((m) => m.isPrivate).single.userId, 1);
  });

  test('Dashboard parses spending and compares with last month', () {
    final d = Dashboard.fromJson({
      'budget': {'month': '2025-05', 'total': 32000, 'spent': 11200, 'lines': []},
      'spending': {'food': 8000, 'transport': 3200},
      'last_month_spent': 10000,
      'recent': [],
    });
    expect(d.spending['food'], 8000);
    expect(d.changeVsLastMonth, closeTo(0.12, 1e-9));

    // An empty PHP map arrives as a list.
    final empty = Dashboard.fromJson({
      'budget': {'month': '2025-05', 'total': 0, 'spent': 0, 'lines': []},
      'spending': [],
      'last_month_spent': 0,
      'recent': [],
    });
    expect(empty.spending, isEmpty);
    expect(empty.changeVsLastMonth, isNull);
  });

  test('FeedItem parses optional amount and subtitle', () {
    final f = FeedItem.fromJson({
      'type': 'goal',
      'user_name': 'Sam',
      'title': 'Sam saved toward Japan Trip',
      'subtitle': null,
      'amount': 5000,
      'at': '2025-05-10T03:00:00Z',
    });
    expect(f.amount, 5000);
    expect(f.subtitle, isNull);
    expect(f.at.isUtc, isFalse);
  });

  test('Bill parses API JSON and describes when it is due', () {
    final bill = Bill.fromJson({
      'id': 4,
      'title': 'Rent',
      'amount': '15000.00',
      'category': 'bills',
      'frequency': 'monthly',
      'next_due_on': '2028-03-05',
      'is_split': 1,
      'user': {'id': 1, 'name': 'Alex'},
    });
    expect(bill.amount, 15000);
    expect(bill.isSplit, isTrue);
    expect(bill.userName, 'Alex');
    expect(bill.daysUntilDue(DateTime(2028, 3, 2, 23, 30)), 3);
    expect(bill.dueLabel(DateTime(2028, 3, 2)), 'Due in 3 days');
    expect(bill.dueLabel(DateTime(2028, 3, 4)), 'Due tomorrow');
    expect(bill.dueLabel(DateTime(2028, 3, 5, 20)), 'Due today');
    expect(bill.dueLabel(DateTime(2028, 3, 8)), 'Overdue by 3 days');
    expect(bill.isOverdue(DateTime(2028, 3, 6)), isTrue);
  });

  test('Dashboard parses upcoming bills, and old payloads without them', () {
    final base = {
      'budget': {'month': '2028-03', 'total': 0, 'spent': 0, 'remaining': 0, 'lines': []},
      'recent': [],
    };
    expect(Dashboard.fromJson(base).upcomingBills, isEmpty);
    final dash = Dashboard.fromJson({
      ...base,
      'upcoming_bills': [
        {'id': 1, 'title': 'Netflix', 'amount': 549, 'category': 'entertainment', 'next_due_on': '2028-03-09'},
      ],
    });
    expect(dash.upcomingBills.single.title, 'Netflix');
    expect(dash.upcomingBills.single.frequency, 'monthly');
  });

  test('TxnDraft.fromTxn copies every field', () {
    final txn = Txn(
      id: 9,
      userId: 2,
      userName: 'Sam',
      type: 'expense',
      amount: 1800,
      category: 'entertainment',
      title: 'Date night',
      paymentMethod: 'card',
      isSplit: true,
      occurredOn: DateTime(2028, 3, 8),
    );
    final d = TxnDraft.fromTxn(txn);
    expect(
      [d.type, d.amount, d.category, d.title, d.paymentMethod, d.isSplit, d.occurredOn],
      ['expense', 1800, 'entertainment', 'Date night', 'card', true, DateTime(2028, 3, 8)],
    );
  });

  test('SplitBalance parses who owes whom, an even balance, and no partner', () {
    final b = SplitBalance.fromJson({
      'owes': {
        'from': {'id': 2, 'name': 'Sam'},
        'to': {'id': 1, 'name': 'Alex'},
        'amount': '415.00',
      },
      'members': [
        {'id': 1, 'name': 'Alex', 'split_paid': 6230, 'paid_this_month': 8730},
        {'id': 2, 'name': 'Sam', 'split_paid': 5400, 'paid_this_month': 9050},
      ],
      'settlements': [
        {
          'id': 3,
          'from_user_id': 2,
          'to_user_id': 1,
          'amount': 200,
          'settled_on': '2028-03-04',
          'from': {'id': 2, 'name': 'Sam'},
          'to': {'id': 1, 'name': 'Alex'},
        },
      ],
    });
    expect([b.owes!.from.name, b.owes!.to.name, b.owes!.amount], ['Sam', 'Alex', 415]);
    expect(b.hasPartner, isTrue);
    expect(b.members.last.paidThisMonth, 9050);
    expect([b.settlements.single.fromName, b.settlements.single.settledOn], ['Sam', DateTime(2028, 3, 4)]);

    final even = SplitBalance.fromJson({
      'owes': null,
      'members': b.members.map((_) => <String, dynamic>{'id': 1, 'name': 'A'}).toList(),
    });
    expect(even.owes, isNull);
    expect(even.settlements, isEmpty);
    expect(SplitBalance.fromJson({'owes': null, 'members': [], 'settlements': []}).hasPartner, isFalse);
  });

  test('TxnDraft.fromTxn keeps who paid', () {
    final txn = Txn(
      id: 1,
      userId: 2,
      userName: 'Sam',
      type: 'expense',
      amount: 10,
      category: 'food',
      title: 'Snack',
      paymentMethod: 'cash',
      isSplit: true,
      occurredOn: DateTime(2028),
    );
    expect(TxnDraft.fromTxn(txn).paidBy, 2);
  });

  test('a transfer into a goal parses, and dashboards know what was saved', () {
    final t = Txn.fromJson({
      'id': 7,
      'user_id': 1,
      'goal_id': 3,
      'type': 'transfer',
      'amount': '1000.00',
      'category': 'savings',
      'title': 'Transfer to Japan Trip',
      'payment_method': 'bank',
      'is_split': false,
      'occurred_on': '2028-03-04',
      'user': {'id': 1, 'name': 'Alex'},
    });
    expect([t.isTransfer, t.isExpense, t.isIncome, t.goalId], [true, false, false, 3]);

    final base = {
      'budget': {'month': '2028-03', 'total': 0, 'spent': 0, 'remaining': 0, 'lines': []},
      'recent': [],
    };
    expect(Dashboard.fromJson(base).savedThisMonth, 0);
    expect(Dashboard.fromJson({...base, 'saved_this_month': '1500.50'}).savedThisMonth, 1500.5);
  });

  test('a bill needs attention from the day before it is due', () {
    Bill dueOn(DateTime d) => Bill(id: 1, title: 'Rent', amount: 1, category: 'bills', frequency: 'monthly', nextDueOn: d);
    final now = DateTime(2028, 3, 10, 21);
    expect(dueOn(DateTime(2028, 3, 12)).needsAttention(now), isFalse);
    expect(dueOn(DateTime(2028, 3, 11)).needsAttention(now), isTrue);
    expect(dueOn(DateTime(2028, 3, 10)).needsAttention(now), isTrue);
    expect(dueOn(DateTime(2028, 3, 1)).needsAttention(now), isTrue);
  });

  test('onboarding answers are sent without anything blank', () {
    const profile = OnboardingProfile(
      partnerName: ' Sam ',
      stage: 'married',
      financialGoals: ['emergency'],
      familyGoals: ['kids'],
      moneyStyle: 'partly',
      monthlyBudget: 30000,
    );
    expect(profile.toJson(), {
      'partner_name': 'Sam',
      'stage': 'married',
      'financial_goals': ['emergency'],
      'family_goals': ['kids'],
      'money_style': 'partly',
      'monthly_budget': 30000.0,
    });
    expect(const OnboardingProfile(partnerName: '  ', monthlyBudget: 0).toJson(), {'financial_goals': [], 'family_goals': []});

    // Before the partner joins, Home uses the name given at onboarding.
    expect(
      const Me(
        user: Member(id: 1, name: 'Alex'),
        partnerName: 'Sam',
      ).coupleNames,
      'Alex & Sam',
    );
    expect(const Me(user: Member(id: 1, name: 'Alex')).coupleNames, 'Alex');
  });

  test('a cancelled goal and its release parse', () {
    final goal = Goal.fromJson({
      'id': 3,
      'name': 'Japan Trip',
      'icon': 'travel',
      'target_amount': 80000,
      'saved': 12000,
      'cancelled_at': '2028-03-04T10:00:00Z',
      'contributor_ids': [1],
    });
    expect(goal.cancelled, isTrue);
    expect(goal.copyWith(restore: true).cancelled, isFalse);
    expect(Goal.fromJson({'id': 1, 'name': 'Home', 'target_amount': 1, 'saved': 0}).cancelled, isFalse);

    final release = Txn.fromJson({
      'id': 9,
      'user_id': 1,
      'goal_id': 3,
      'type': 'release',
      'amount': 12000,
      'category': 'savings',
      'title': 'Released from Japan Trip',
      'occurred_on': '2028-03-04',
    });
    expect([release.isRelease, release.isTransfer, release.isExpense, release.isIncome], [true, false, false, false]);
  });

  test('members carry a photo version only when they have a photo', () {
    expect(Member.fromJson({'id': 1, 'name': 'Alex', 'avatar_version': 1760000000000}).avatarVersion, 1760000000000);
    expect(Member.fromJson({'id': 2, 'name': 'Sam', 'avatar_version': null}).avatarVersion, isNull);
    expect(Member.fromJson({'id': 3, 'name': 'Robin'}).avatarVersion, isNull);
  });
}
