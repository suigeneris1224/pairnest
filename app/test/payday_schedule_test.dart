import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/data/models.dart';
import 'package:pairnest/data/payday_schedule.dart';

void main() {
  test('twice a month alternates between the two days, using the last day of short months', () {
    expect(nextPayday('semimonthly', DateTime(2026, 10, 15), [15, 30]), DateTime(2026, 10, 30));
    expect(nextPayday('semimonthly', DateTime(2026, 10, 30), [15, 30]), DateTime(2026, 11, 15));
    expect(nextPayday('semimonthly', DateTime(2027, 2, 15), [15, 30]), DateTime(2027, 2, 28));
    expect(nextPayday('semimonthly', DateTime(2027, 2, 28), [15, 30]), DateTime(2027, 3, 15));
    expect(nextPayday('semimonthly', DateTime(2026, 12, 31), [10, 31]), DateTime(2027, 1, 10));
  });

  test('monthly returns to its day after a short month; weekly and every 2 weeks add days', () {
    expect(nextPayday('monthly', DateTime(2027, 1, 31), [31]), DateTime(2027, 2, 28));
    expect(nextPayday('monthly', DateTime(2027, 2, 28), [31]), DateTime(2027, 3, 31));
    expect(nextPayday('weekly', DateTime(2026, 12, 29), const []), DateTime(2027, 1, 5));
    expect(nextPayday('biweekly', DateTime(2027, 2, 19), const []), DateTime(2027, 3, 5));
  });

  test('the first payday on or after today', () {
    expect(firstPaydayOnOrAfter([30, 15], DateTime(2026, 10, 16)), DateTime(2026, 10, 30));
    expect(firstPaydayOnOrAfter([15, 30], DateTime(2026, 10, 15)), DateTime(2026, 10, 15));
    expect(firstPaydayOnOrAfter([15, 30], DateTime(2026, 10, 31)), DateTime(2026, 11, 15));
    expect(firstPaydayOnOrAfter([30], DateTime(2027, 2, 20)), DateTime(2027, 2, 28));
    expect(firstPaydayOnOrAfter([5], DateTime(2026, 12, 20)), DateTime(2027, 1, 5));
  });

  test("the daily allowance splits what's left across the days until payday, or until month end", () {
    expect(dailyAllowance(remaining: 3000, today: DateTime(2026, 10, 12), payday: DateTime(2026, 10, 15)), 1000);
    // Payday next month: the budget starts over on the 1st, so only Oct 28–31 count.
    expect(dailyAllowance(remaining: 4000, today: DateTime(2026, 10, 28), payday: DateTime(2026, 11, 5)), 1000);
    expect(dailyAllowance(remaining: 0, today: DateTime(2026, 10, 12), payday: DateTime(2026, 10, 15)), isNull);
  });

  test('labels', () {
    Payday payday(String frequency, List<int> days) =>
        Payday(id: 1, userId: 1, title: 'Salary', amount: 1, frequency: frequency, nextOn: DateTime(2026, 10, 15), days: days);
    expect(payday('semimonthly', [15, 30]).scheduleLabel, '15th & 30th');
    expect(payday('monthly', [1]).scheduleLabel, 'Monthly · 1st');
    expect(payday('monthly', [22]).scheduleLabel, 'Monthly · 22nd');
    expect(payday('monthly', [11]).scheduleLabel, 'Monthly · 11th');
    expect(payday('biweekly', const []).scheduleLabel, 'Every 2 weeks');
    final p = payday('weekly', const []);
    expect(p.whenLabel(DateTime(2026, 10, 12)), 'Payday in 3 days');
    expect(p.whenLabel(DateTime(2026, 10, 15, 18)), 'Payday today');
    expect(p.whenLabel(DateTime(2026, 10, 17)), 'Payday was 2 days ago');
    expect(p.isDue(DateTime(2026, 10, 14)), isFalse);
    expect(p.isDue(DateTime(2026, 10, 15)), isTrue);
  });
}
