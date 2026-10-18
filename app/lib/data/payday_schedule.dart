/// Pay schedules, matching the server's Payday model: short months use their
/// last day, so "the 30th" is Feb 28.
library;

const payFrequencies = ['semimonthly', 'monthly', 'biweekly', 'weekly'];

/// Frequencies set by days of the month rather than a start date.
bool isByDay(String frequency) => frequency == 'semimonthly' || frequency == 'monthly';

DateTime _onDay(int year, int month, int day) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > last ? last : day);
}

/// The payday after [on].
DateTime nextPayday(String frequency, DateTime on, List<int> days) {
  final d = DateTime(on.year, on.month, on.day);
  switch (frequency) {
    case 'weekly':
      return DateTime(d.year, d.month, d.day + 7);
    case 'biweekly':
      return DateTime(d.year, d.month, d.day + 14);
    case 'monthly':
      return _onDay(d.year, d.month + 1, days.first);
    default:
      final second = _onDay(d.year, d.month, days.last);
      return d.day < second.day ? second : _onDay(d.year, d.month + 1, days.first);
  }
}

/// The first payday on or after [today] for a monthly or twice-a-month schedule.
DateTime firstPaydayOnOrAfter(List<int> days, DateTime today) {
  final sorted = [...days]..sort();
  final t = DateTime(today.year, today.month, today.day);
  for (final m in [0, 1]) {
    for (final day in sorted) {
      final candidate = _onDay(t.year, t.month + m, day);
      if (!candidate.isBefore(t)) return candidate;
    }
  }
  return _onDay(t.year, t.month + 1, sorted.first);
}

/// What's left of the budget per day until the next payday, counting today.
/// Stops at month end, when the budget starts over. Null when nothing's left.
double? dailyAllowance({required double remaining, required DateTime today, required DateTime payday}) {
  if (remaining <= 0) return null;
  final t = DateTime(today.year, today.month, today.day);
  final monthEnd = DateTime(t.year, t.month + 1, 0);
  final until = payday.isAfter(monthEnd) ? monthEnd.add(const Duration(days: 1)) : payday;
  final days = DateTime(until.year, until.month, until.day).difference(t).inDays;
  return remaining / (days < 1 ? 1 : days);
}

String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return '$n${switch (n % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  }}';
}
