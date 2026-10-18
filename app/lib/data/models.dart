import 'payday_schedule.dart';

double _num(Object? v) => v == null ? 0 : (v is num ? v.toDouble() : double.parse(v.toString()));

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v.toString()).toLocal();

class Member {
  const Member({required this.id, required this.name, this.avatarVersion});

  factory Member.fromJson(Map<String, dynamic> j) =>
      Member(id: j['id'] as int, name: j['name'] as String, avatarVersion: (j['avatar_version'] as num?)?.toInt());

  final int id;
  final String name;

  /// Changes whenever their profile photo does; null when they have none.
  final int? avatarVersion;
}

/// Onboarding answers. Only the name is required; everything here is optional.
class OnboardingProfile {
  const OnboardingProfile({
    this.partnerName,
    this.stage,
    this.financialGoals = const [],
    this.familyGoals = const [],
    this.moneyStyle,
    this.monthlyBudget,
  });

  final String? partnerName;
  final String? stage;
  final List<String> financialGoals;
  final List<String> familyGoals;
  final String? moneyStyle;
  final double? monthlyBudget;

  Map<String, dynamic> toJson() => {
    if (partnerName != null && partnerName!.trim().isNotEmpty) 'partner_name': partnerName!.trim(),
    if (stage != null) 'stage': stage,
    'financial_goals': financialGoals,
    'family_goals': familyGoals,
    if (moneyStyle != null) 'money_style': moneyStyle,
    if (monthlyBudget != null && monthlyBudget! > 0) 'monthly_budget': monthlyBudget,
  };
}

class Couple {
  const Couple({required this.id, required this.inviteCode, required this.theme, required this.members, this.stage});

  factory Couple.fromJson(Map<String, dynamic> j) => Couple(
    id: j['id'] as int,
    inviteCode: j['invite_code'] as String,
    theme: j['theme'] as String,
    members: [for (final m in (j['members'] as List? ?? const [])) Member.fromJson(m as Map<String, dynamic>)],
    stage: j['stage'] as String?,
  );

  final int id;
  final String inviteCode;
  final String theme;
  final List<Member> members;

  /// Relationship stage from onboarding: dating, engaged, married, living_together.
  final String? stage;

  Couple copyWith({String? theme, List<Member>? members}) =>
      Couple(id: id, inviteCode: inviteCode, theme: theme ?? this.theme, members: members ?? this.members, stage: stage);

  int indexOf(int userId) {
    final i = members.indexWhere((m) => m.id == userId);
    return i < 0 ? 0 : i;
  }
}

/// The signed-in user plus their nest, if paired.
class Me {
  const Me({required this.user, this.couple, this.partnerName});

  factory Me.fromJson(Map<String, dynamic> j) => Me(
    user: Member.fromJson(j),
    couple: j['couple'] == null ? null : Couple.fromJson(j['couple'] as Map<String, dynamic>),
    partnerName: (j['profile'] as Map?)?['partner_name'] as String?,
  );

  final Member user;
  final Couple? couple;

  /// The partner's name from onboarding, before they've joined.
  final String? partnerName;

  Member? get partner {
    for (final m in couple?.members ?? const <Member>[]) {
      if (m.id != user.id) return m;
    }
    return null;
  }

  /// "Alex & Sam"; uses the partner's name from onboarding until they join.
  String get coupleNames {
    final other = partner?.name ?? partnerName;
    return other == null ? user.name : '${user.name} & $other';
  }
}

class Txn {
  const Txn({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    required this.amount,
    required this.category,
    required this.title,
    required this.paymentMethod,
    required this.isSplit,
    required this.occurredOn,
    this.goalId,
  });

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
    id: j['id'] as int,
    userId: j['user_id'] as int,
    userName: ((j['user'] as Map?)?['name'] ?? '') as String,
    type: j['type'] as String,
    amount: _num(j['amount']),
    category: j['category'] as String,
    title: j['title'] as String,
    paymentMethod: (j['payment_method'] ?? 'cash') as String,
    isSplit: j['is_split'] == true || j['is_split'] == 1,
    occurredOn: DateTime.parse(j['occurred_on'] as String),
    goalId: j['goal_id'] as int?,
  );

  final int id;
  final int userId;
  final String userName;
  final String type;
  final double amount;
  final String category;
  final String title;
  final String paymentMethod;
  final bool isSplit;
  final DateTime occurredOn;

  /// The goal a transfer moved money into.
  final int? goalId;

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  /// Money moved into a goal: saved, not spent.
  bool get isTransfer => type == 'transfer';

  /// A cancelled goal's savings given back.
  bool get isRelease => type == 'release';
}

class TxnDraft {
  const TxnDraft({
    required this.type,
    required this.amount,
    required this.category,
    required this.title,
    required this.paymentMethod,
    required this.isSplit,
    required this.occurredOn,
    this.paidBy,
  });

  /// A copy of [t]'s fields, used to edit it or to restore it after a delete.
  factory TxnDraft.fromTxn(Txn t) => TxnDraft(
    type: t.type,
    amount: t.amount,
    category: t.category,
    title: t.title,
    paymentMethod: t.paymentMethod,
    isSplit: t.isSplit,
    occurredOn: t.occurredOn,
    paidBy: t.userId,
  );

  final String type;
  final double amount;
  final String category;
  final String title;
  final String paymentMethod;
  final bool isSplit;
  final DateTime occurredOn;

  /// Member who paid; null means whoever logs it.
  final int? paidBy;
}

class BudgetLine {
  const BudgetLine({required this.category, required this.limit, required this.spent});

  factory BudgetLine.fromJson(Map<String, dynamic> j) =>
      BudgetLine(category: j['category'] as String, limit: _num(j['limit']), spent: _num(j['spent']));

  final String category;
  final double limit;
  final double spent;

  double get remaining => limit - spent;
  double get ratio => limit <= 0 ? 0 : spent / limit;
}

class BudgetSummary {
  const BudgetSummary({required this.month, required this.total, required this.spent, required this.lines});

  factory BudgetSummary.fromJson(Map<String, dynamic> j) => BudgetSummary(
    month: DateTime.parse('${j['month']}-01'),
    total: _num(j['total']),
    spent: _num(j['spent']),
    lines: [for (final l in j['lines'] as List) BudgetLine.fromJson(l as Map<String, dynamic>)],
  );

  final DateTime month;
  final double total;
  final double spent;
  final List<BudgetLine> lines;

  double get remaining => total - spent;
  double get ratio => total <= 0 ? 0 : spent / total;
}

/// A recurring bill; paying it logs an expense and moves [nextDueOn] on.
class Bill {
  const Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.nextDueOn,
    this.isSplit = true,
    this.userName = '',
  });

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
    id: j['id'] as int,
    title: j['title'] as String,
    amount: _num(j['amount']),
    category: j['category'] as String,
    frequency: (j['frequency'] ?? 'monthly') as String,
    nextDueOn: DateTime.parse(j['next_due_on'] as String),
    isSplit: j['is_split'] == true || j['is_split'] == 1,
    userName: ((j['user'] as Map?)?['name'] ?? '') as String,
  );

  final int id;
  final String title;
  final double amount;
  final String category;
  final String frequency;
  final DateTime nextDueOn;
  final bool isSplit;
  final String userName;

  bool get isWeekly => frequency == 'weekly';

  /// Whole days until due; negative when overdue.
  int daysUntilDue([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(nextDueOn.year, nextDueOn.month, nextDueOn.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  }

  bool isOverdue([DateTime? now]) => daysUntilDue(now) < 0;

  /// Overdue, due today or due tomorrow: worth a reminder.
  bool needsAttention([DateTime? now]) => daysUntilDue(now) <= 1;

  /// "Due today", "Due tomorrow", "Due in 3 days", "Overdue by 2 days".
  String dueLabel([DateTime? now]) {
    final d = daysUntilDue(now);
    return switch (d) {
      0 => 'Due today',
      1 => 'Due tomorrow',
      -1 => 'Overdue by 1 day',
      < 0 => 'Overdue by ${-d} days',
      _ => 'Due in $d days',
    };
  }
}

class BillDraft {
  const BillDraft({
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.nextDueOn,
    this.isSplit = true,
  });

  final String title;
  final double amount;
  final String category;
  final String frequency;
  final DateTime nextDueOn;
  final bool isSplit;
}

/// One partner's pay schedule. Logging it on payday records income.
class Payday {
  const Payday({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.frequency,
    required this.nextOn,
    this.days = const [],
    this.isSplit = true,
    this.userName = '',
  });

  factory Payday.fromJson(Map<String, dynamic> j) => Payday(
    id: j['id'] as int,
    userId: j['user_id'] as int,
    title: j['title'] as String,
    amount: _num(j['amount']),
    frequency: j['frequency'] as String,
    nextOn: DateTime.parse(j['next_on'] as String),
    days: [for (final d in (j['days'] ?? const []) as List) (d as num).toInt()],
    isSplit: j['is_split'] == true || j['is_split'] == 1,
    userName: ((j['user'] as Map?)?['name'] ?? '') as String,
  );

  final int id;
  final int userId;
  final String title;
  final double amount;

  /// One of [payFrequencies].
  final String frequency;
  final DateTime nextOn;

  /// Days of the month for monthly and twice-a-month pay, e.g. [15, 30].
  final List<int> days;
  final bool isSplit;
  final String userName;

  /// Whole days until payday; zero on the day, negative once it's passed unlogged.
  int daysUntil(DateTime now) => DateTime(nextOn.year, nextOn.month, nextOn.day).difference(DateTime(now.year, now.month, now.day)).inDays;

  /// Payday has come and the pay isn't logged yet.
  bool isDue(DateTime now) => daysUntil(now) <= 0;

  /// "15th & 30th", "Monthly · 25th", "Every 2 weeks", "Every week".
  String get scheduleLabel => switch (frequency) {
    'semimonthly' when days.length == 2 => '${ordinal(days[0])} & ${ordinal(days[1])}',
    'monthly' when days.isNotEmpty => 'Monthly · ${ordinal(days[0])}',
    'biweekly' => 'Every 2 weeks',
    'weekly' => 'Every week',
    _ => 'Twice a month',
  };

  /// "Payday today", "Payday tomorrow", "Payday in 3 days", "Payday was 2 days ago".
  String whenLabel(DateTime now) {
    final d = daysUntil(now);
    return switch (d) {
      0 => 'Payday today',
      1 => 'Payday tomorrow',
      -1 => 'Payday was yesterday',
      < 0 => 'Payday was ${-d} days ago',
      _ => 'Payday in $d days',
    };
  }
}

class PaydayDraft {
  const PaydayDraft({
    this.title = 'Salary',
    required this.amount,
    required this.frequency,
    this.days = const [],
    this.nextOn,
    this.isSplit = true,
  });

  final String title;
  final double amount;
  final String frequency;

  /// For monthly (one day) and twice-a-month (two days) pay.
  final List<int> days;

  /// For weekly and every-2-weeks pay.
  final DateTime? nextOn;
  final bool isSplit;
}

/// One partner paying the other back for shared expenses.
class Settlement {
  const Settlement({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.amount,
    required this.settledOn,
  });

  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
    id: j['id'] as int,
    fromId: j['from_user_id'] as int,
    fromName: ((j['from'] as Map?)?['name'] ?? '') as String,
    toId: j['to_user_id'] as int,
    toName: ((j['to'] as Map?)?['name'] ?? '') as String,
    amount: _num(j['amount']),
    settledOn: DateTime.parse(j['settled_on'] as String),
  );

  final int id;
  final int fromId;
  final String fromName;
  final int toId;
  final String toName;
  final double amount;
  final DateTime settledOn;
}

/// What one partner has paid: split expenses ever, and everything this month.
class MemberPaid {
  const MemberPaid({required this.id, required this.name, required this.splitPaid, required this.paidThisMonth});

  factory MemberPaid.fromJson(Map<String, dynamic> j) => MemberPaid(
    id: j['id'] as int,
    name: j['name'] as String,
    splitPaid: _num(j['split_paid']),
    paidThisMonth: _num(j['paid_this_month']),
  );

  final int id;
  final String name;
  final double splitPaid;
  final double paidThisMonth;
}

/// Who owes whom, as a running total of split expenses less settlements.
class SplitBalance {
  const SplitBalance({this.owes, this.members = const [], this.settlements = const []});

  factory SplitBalance.fromJson(Map<String, dynamic> j) {
    final owes = j['owes'] as Map<String, dynamic>?;
    return SplitBalance(
      owes: owes == null
          ? null
          : Owes(
              from: Member.fromJson(owes['from'] as Map<String, dynamic>),
              to: Member.fromJson(owes['to'] as Map<String, dynamic>),
              amount: _num(owes['amount']),
            ),
      members: [for (final m in (j['members'] as List? ?? const [])) MemberPaid.fromJson(m as Map<String, dynamic>)],
      settlements: [for (final s in (j['settlements'] as List? ?? const [])) Settlement.fromJson(s as Map<String, dynamic>)],
    );
  }

  /// Null when you're even.
  final Owes? owes;
  final List<MemberPaid> members;
  final List<Settlement> settlements;

  /// False until the partner has joined.
  bool get hasPartner => members.length == 2;
}

class Owes {
  const Owes({required this.from, required this.to, required this.amount});

  final Member from;
  final Member to;
  final double amount;
}

class Dashboard {
  const Dashboard({
    required this.budget,
    required this.recent,
    this.spending = const {},
    this.lastMonthSpent = 0,
    this.upcomingBills = const [],
    this.savedThisMonth = 0,
    this.paydays = const [],
  });

  factory Dashboard.fromJson(Map<String, dynamic> j) {
    final spending = j['spending'];
    return Dashboard(
      budget: BudgetSummary.fromJson(j['budget'] as Map<String, dynamic>),
      recent: [for (final t in j['recent'] as List) Txn.fromJson(t as Map<String, dynamic>)],
      // An empty PHP map arrives as [] rather than {}.
      spending: spending is Map ? {for (final e in spending.entries) e.key as String: _num(e.value)} : const {},
      lastMonthSpent: _num(j['last_month_spent']),
      upcomingBills: [for (final b in (j['upcoming_bills'] ?? const []) as List) Bill.fromJson(b as Map<String, dynamic>)],
      savedThisMonth: _num(j['saved_this_month']),
      paydays: [for (final d in (j['paydays'] ?? const []) as List) Payday.fromJson(d as Map<String, dynamic>)],
    );
  }

  final BudgetSummary budget;
  final List<Txn> recent;

  /// Overdue bills and those due within two weeks, soonest first.
  final List<Bill> upcomingBills;

  /// Every expense category this month, budgeted or not.
  final Map<String, double> spending;
  final double lastMonthSpent;

  /// Transferred into goals this month; savings, not spending.
  final double savedThisMonth;

  /// Both partners' pay schedules, soonest first.
  final List<Payday> paydays;

  /// Spending change vs last month as a fraction (0.12 = 12% more), or null
  /// when there's nothing to compare against.
  double? get changeVsLastMonth => lastMonthSpent <= 0 ? null : (budget.spent - lastMonthSpent) / lastMonthSpent;
}

/// One thing your partner did, for the notification feed.
class FeedItem {
  const FeedItem({required this.type, required this.userName, required this.title, this.subtitle, this.amount, required this.at});

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
    type: j['type'] as String,
    userName: (j['user_name'] ?? '') as String,
    title: j['title'] as String,
    subtitle: j['subtitle'] as String?,
    amount: j['amount'] == null ? null : _num(j['amount']),
    at: _date(j['at'])!,
  );

  final String type;
  final String userName;
  final String title;
  final String? subtitle;
  final double? amount;
  final DateTime at;
}

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.target,
    required this.saved,
    required this.targetDate,
    required this.contributorIds,
    this.cancelledAt,
  });

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    id: j['id'] as int,
    name: j['name'] as String,
    subtitle: (j['subtitle'] ?? '') as String,
    icon: (j['icon'] ?? 'star') as String,
    target: _num(j['target_amount']),
    saved: _num(j['saved']),
    targetDate: j['target_date'] == null ? null : DateTime.parse(j['target_date'] as String),
    contributorIds: [for (final id in (j['contributor_ids'] as List? ?? const [])) id as int],
    cancelledAt: _date(j['cancelled_at']),
  );

  final int id;
  final String name;
  final String subtitle;
  final String icon;
  final double target;
  final double saved;
  final DateTime? targetDate;
  final List<int> contributorIds;

  /// When the couple cancelled it; its savings were released then.
  final DateTime? cancelledAt;

  bool get cancelled => cancelledAt != null;

  double get ratio => target <= 0 ? 0 : (saved / target).clamp(0, 1);

  Goal copyWith({
    String? name,
    String? subtitle,
    String? icon,
    double? target,
    double? saved,
    DateTime? targetDate,
    List<int>? contributorIds,
    DateTime? cancelledAt,
    bool restore = false,
  }) => Goal(
    id: id,
    name: name ?? this.name,
    subtitle: subtitle ?? this.subtitle,
    icon: icon ?? this.icon,
    target: target ?? this.target,
    saved: saved ?? this.saved,
    targetDate: targetDate ?? this.targetDate,
    contributorIds: contributorIds ?? this.contributorIds,
    cancelledAt: restore ? null : cancelledAt ?? this.cancelledAt,
  );
}

class Mood {
  const Mood({
    required this.id,
    required this.userId,
    required this.userName,
    required this.mood,
    required this.note,
    required this.isPrivate,
    required this.createdAt,
  });

  factory Mood.fromJson(Map<String, dynamic> j) => Mood(
    id: j['id'] as int,
    userId: j['user_id'] as int,
    userName: ((j['user'] as Map?)?['name'] ?? '') as String,
    mood: j['mood'] as String,
    note: (j['note'] ?? '') as String,
    isPrivate: j['is_private'] == true || j['is_private'] == 1,
    createdAt: _date(j['created_at'])!,
  );

  final int id;
  final int userId;
  final String userName;
  final String mood;
  final String note;
  final bool isPrivate;
  final DateTime createdAt;
}

class TalkAnswer {
  const TalkAnswer({required this.userId, required this.userName, required this.answer});

  factory TalkAnswer.fromJson(Map<String, dynamic> j) =>
      TalkAnswer(userId: j['user_id'] as int, userName: ((j['user'] as Map?)?['name'] ?? '') as String, answer: j['answer'] as String);

  final int userId;
  final String userName;
  final String answer;
}

class Prompt {
  const Prompt({required this.id, required this.topic, required this.question});

  factory Prompt.fromJson(Map<String, dynamic> j) =>
      Prompt(id: j['id'] as int, topic: j['topic'] as String, question: j['question'] as String);

  final int id;
  final String topic;
  final String question;
}

class TalkState {
  const TalkState({required this.prompt, required this.answered, required this.answers});

  factory TalkState.fromJson(Map<String, dynamic> j) => TalkState(
    prompt: Prompt.fromJson(j['prompt'] as Map<String, dynamic>),
    answered: j['answered'] == true,
    answers: [for (final a in j['answers'] as List) TalkAnswer.fromJson(a as Map<String, dynamic>)],
  );

  final Prompt prompt;
  final bool answered;
  final List<TalkAnswer> answers;
}

class PastTalk {
  const PastTalk({required this.prompt, required this.lastAnsweredAt, required this.answers});

  factory PastTalk.fromJson(Map<String, dynamic> j) => PastTalk(
    prompt: Prompt.fromJson(j['prompt'] as Map<String, dynamic>),
    lastAnsweredAt: _date(j['last_answered_at'])!,
    answers: [for (final a in j['answers'] as List) TalkAnswer.fromJson(a as Map<String, dynamic>)],
  );

  final Prompt prompt;
  final DateTime lastAnsweredAt;
  final List<TalkAnswer> answers;
}

class Plan {
  const Plan({
    required this.id,
    required this.kind,
    required this.title,
    required this.notes,
    required this.scheduledAt,
    required this.goal,
  });

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
    id: j['id'] as int,
    kind: j['kind'] as String,
    title: j['title'] as String,
    notes: (j['notes'] ?? '') as String,
    scheduledAt: _date(j['scheduled_at']),
    goal: j['goal'] == null ? null : Goal.fromJson(j['goal'] as Map<String, dynamic>),
  );

  final int id;
  final String kind;
  final String title;
  final String notes;
  final DateTime? scheduledAt;
  final Goal? goal;

  bool get isDate => kind == 'date';
}
