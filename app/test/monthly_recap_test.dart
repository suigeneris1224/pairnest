import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/data/models.dart';
import 'package:pairnest/features/recap/monthly_recap.dart';

const _alex = Member(id: 1, name: 'Alex');
const _sam = Member(id: 2, name: 'Sam');
var _id = 0;

Txn _t(double amount, {String type = 'expense', String category = 'food', int userId = 1, int day = 5, int month = 3, int? goalId}) => Txn(
  id: ++_id,
  userId: userId,
  userName: userId == 1 ? 'Alex' : 'Sam',
  type: type,
  amount: amount,
  category: category,
  title: 'T$_id',
  paymentMethod: 'cash',
  isSplit: true,
  occurredOn: DateTime(2028, month, day),
  goalId: goalId,
);

BudgetSummary _budget(double total) => BudgetSummary(month: DateTime(2028, 3), total: total, spent: 0, lines: const []);

Goal _goal(int id, String name, double saved, double target, {bool cancelled = false}) => Goal(
  id: id,
  name: name,
  subtitle: '',
  icon: 'star',
  target: target,
  saved: saved,
  targetDate: null,
  contributorIds: const [],
  cancelledAt: cancelled ? DateTime(2028, 3, 20) : null,
);

MonthlyRecap _build(
  List<Txn> txns, {
  List<Txn> previous = const [],
  BudgetSummary? budget,
  List<Goal> goals = const [],
  List<Mood> moods = const [],
}) => MonthlyRecap.build(
  month: DateTime(2028, 3),
  txns: txns,
  previousTxns: previous,
  budget: budget,
  goals: goals,
  moods: moods,
  members: const [_alex, _sam],
);

void main() {
  test('verdicts: under, over, no budget and quiet', () {
    final txns = [_t(800), _t(200, category: 'bills', userId: 2)];
    expect(_build(txns, budget: _budget(2000)).verdict, RecapVerdict.underBudget);
    expect(_build(txns, budget: _budget(2000)).underBy, 1000);
    expect(_build(txns, budget: _budget(600)).verdict, RecapVerdict.overBudget);
    expect(_build(txns, budget: _budget(600)).overBy, 400);
    expect(_build(txns).verdict, RecapVerdict.noBudget);
    expect(_build(const []).verdict, RecapVerdict.quiet);
    expect(_build(const []).isEmpty, isTrue);
  });

  test('top categories, who paid, biggest expense and month comparison', () {
    final r = _build(
      [
        _t(500, category: 'food'),
        _t(300, category: 'food', userId: 2),
        _t(1200, category: 'bills', userId: 2),
        _t(100, category: 'transport'),
        _t(50, category: 'fun'),
        _t(9999, type: 'income', category: 'income'),
        _t(700, month: 2), // last month; ignored here
      ],
      previous: [
        _t(1000, month: 2),
        _t(9999, type: 'income', category: 'income', month: 2),
      ],
    );
    expect(r.spent, 2150);
    expect(r.income, 9999);
    expect(r.topCategories.map((c) => c.$1), ['bills', 'food', 'transport']);
    expect(r.topCategories.first.$3, closeTo(1200 / 2150, 1e-9));
    expect(r.paidBy.first.member.name, 'Sam');
    expect(r.paidBy.first.amount, 1500);
    expect(r.paidBy.last.share, closeTo(650 / 2150, 1e-9));
    expect(r.biggestExpense!.amount, 1200);
    expect(r.changeVsLastMonth, closeTo(1.15, 1e-9));
    expect(r.txnCount, 6);
  });

  test('savings are net of releases, and completed goals need a transfer this month', () {
    final goals = [
      _goal(1, 'Japan Trip', 80000, 80000),
      _goal(2, 'Emergency Fund', 50000, 50000), // complete, but funded earlier
      _goal(3, 'Car', 3000, 300000, cancelled: true),
    ];
    final r = _build([
      _t(5000, type: 'transfer', category: 'savings', goalId: 1),
      _t(3000, type: 'transfer', category: 'savings', goalId: 3),
      _t(3000, type: 'release', category: 'savings', goalId: 3),
    ], goals: goals);
    expect(r.savedNet, 5000);
    expect(r.savedByGoal, {'Japan Trip': 5000});
    expect(r.goalsCompleted, ['Japan Trip']);
    expect(r.spent, 0);
  });

  test('check-ins count this month and find the most common mood', () {
    Mood mood(String m, int day, {int month = 3}) =>
        Mood(id: day, userId: 1, userName: 'Alex', mood: m, note: '', isPrivate: false, createdAt: DateTime(2028, month, day, 9));
    final r = _build([_t(10)], moods: [mood('calm', 1), mood('happy', 2), mood('happy', 3), mood('tired', 4, month: 2)]);
    expect(r.checkIns, 3);
    expect(r.topMood, 'happy');
  });
}
