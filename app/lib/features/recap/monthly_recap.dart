import '../../data/models.dart';

enum RecapVerdict { underBudget, overBudget, noBudget, quiet }

/// One member's share of the month's spending.
class PaidShare {
  const PaidShare(this.member, this.amount, this.share);

  final Member member;
  final double amount;

  /// 0…1 of the month's expenses.
  final double share;
}

/// A month at a glance: spending against the budget, top categories,
/// savings, who paid and the couple's check-ins. Pure, so it's built the
/// same way in demo mode and against the API.
class MonthlyRecap {
  const MonthlyRecap({
    required this.month,
    required this.spent,
    required this.income,
    required this.budgetTotal,
    required this.changeVsLastMonth,
    required this.topCategories,
    required this.savedNet,
    required this.savedByGoal,
    required this.goalsCompleted,
    required this.paidBy,
    required this.checkIns,
    required this.topMood,
    required this.txnCount,
    required this.biggestExpense,
  });

  factory MonthlyRecap.build({
    required DateTime month,
    required List<Txn> txns,
    required List<Txn> previousTxns,
    required BudgetSummary? budget,
    required List<Goal> goals,
    required List<Mood> moods,
    required List<Member> members,
  }) {
    bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;
    final monthTxns = [
      for (final t in txns)
        if (inMonth(t.occurredOn)) t,
    ];
    final expenses = [
      for (final t in monthTxns)
        if (t.isExpense) t,
    ];
    double sum(Iterable<Txn> xs) => xs.fold(0, (a, t) => a + t.amount);

    final spent = sum(expenses);
    final previous = sum(previousTxns.where((t) => t.isExpense));

    final byCategory = <String, double>{};
    for (final t in expenses) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }
    final top = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Savings: transfers in, less anything released from cancelled goals.
    final goalNames = {for (final g in goals) g.id: g.name};
    final savedByGoal = <String, double>{};
    for (final t in monthTxns.where((t) => t.isTransfer || t.isRelease)) {
      final name = goalNames[t.goalId] ?? 'A goal';
      savedByGoal[name] = (savedByGoal[name] ?? 0) + (t.isRelease ? -t.amount : t.amount);
    }
    savedByGoal.removeWhere((_, v) => v <= 0);
    final fundedGoalIds = {
      for (final t in monthTxns)
        if (t.isTransfer) t.goalId,
    };
    final completed = [
      for (final g in goals)
        if (!g.cancelled && g.target > 0 && g.saved >= g.target && fundedGoalIds.contains(g.id)) g.name,
    ];

    final paid = [
      for (final m in members)
        () {
          final amount = sum(expenses.where((t) => t.userId == m.id));
          return PaidShare(m, amount, spent <= 0 ? 0 : amount / spent);
        }(),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    final monthMoods = [
      for (final m in moods)
        if (inMonth(m.createdAt)) m,
    ];
    final moodCounts = <String, int>{};
    for (final m in monthMoods) {
      moodCounts[m.mood] = (moodCounts[m.mood] ?? 0) + 1;
    }
    final topMood = (moodCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).firstOrNull?.key;

    Txn? biggest;
    for (final t in expenses) {
      if (biggest == null || t.amount > biggest.amount) biggest = t;
    }

    return MonthlyRecap(
      month: DateTime(month.year, month.month),
      spent: spent,
      income: sum(monthTxns.where((t) => t.isIncome)),
      budgetTotal: budget?.total ?? 0,
      changeVsLastMonth: previous <= 0 || spent <= 0 ? null : (spent - previous) / previous,
      topCategories: [for (final e in top.take(3)) (e.key, e.value, spent <= 0 ? 0.0 : e.value / spent)],
      savedNet: savedByGoal.values.fold(0.0, (a, b) => a + b),
      savedByGoal: savedByGoal,
      goalsCompleted: completed,
      paidBy: paid,
      checkIns: monthMoods.length,
      topMood: topMood,
      txnCount: monthTxns.length,
      biggestExpense: biggest,
    );
  }

  final DateTime month;
  final double spent;
  final double income;
  final double budgetTotal;

  /// Fraction vs the previous month (0.08 = 8% more), or null.
  final double? changeVsLastMonth;

  /// Up to three (category key, amount, share of spending).
  final List<(String, double, double)> topCategories;
  final double savedNet;
  final Map<String, double> savedByGoal;
  final List<String> goalsCompleted;

  /// Biggest payer first.
  final List<PaidShare> paidBy;
  final int checkIns;
  final String? topMood;
  final int txnCount;
  final Txn? biggestExpense;

  bool get isEmpty => txnCount == 0 && checkIns == 0;

  RecapVerdict get verdict {
    if (txnCount == 0) return RecapVerdict.quiet;
    if (budgetTotal <= 0) return RecapVerdict.noBudget;
    return spent <= budgetTotal ? RecapVerdict.underBudget : RecapVerdict.overBudget;
  }

  double get underBy => budgetTotal - spent;
  double get overBy => spent - budgetTotal;
  double get budgetRatio => budgetTotal <= 0 ? 0 : spent / budgetTotal;
}
