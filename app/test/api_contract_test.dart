// Runs ApiRepository against a live backend to check every JSON shape parses.
// Skipped unless API_URL is set:
//
//   php artisan migrate:fresh --seed && php artisan serve --port=8800
//   flutter test test/api_contract_test.dart --dart-define=API_URL=http://127.0.0.1:8800/api/v1
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/data/api_repository.dart';
import 'package:pairnest/data/models.dart';
import 'package:pairnest/data/providers.dart';

void main() {
  test('full couple flow against the live API', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final alex = ApiRepository(apiUrl);
    final sam = ApiRepository(apiUrl);

    // No email or password: onboarding answers and a recovery key.
    final a = await alex.start('Alex', const OnboardingProfile(partnerName: 'Sam', stage: 'married'));
    expect(a.me.couple, isNull);
    expect(a.me.partnerName, 'Sam');
    expect(a.recoveryKey, matches(RegExp(r'^[A-Z2-9]{4}(-[A-Z2-9]{4}){3}$')));
    final nest = await alex.createNest('lavender');
    expect(nest.couple!.theme, 'lavender');
    expect(nest.couple!.stage, 'married');

    await sam.start('Sam', const OnboardingProfile());
    final joined = await sam.joinNest(nest.couple!.inviteCode);
    expect(joined.partner!.name, 'Alex');

    final month = DateTime.now();
    await alex.saveBudget(month, 20000, {'food': 5000});
    await alex.addTransaction(
      TxnDraft(
        type: 'expense',
        amount: 1250,
        category: 'food',
        title: 'Groceries',
        paymentMethod: 'gcash',
        isSplit: true,
        occurredOn: month,
      ),
    );
    final groceries = (await sam.transactions(month: month)).single;
    final edited = await sam.updateTransaction(groceries.id, TxnDraft.fromTxn(groceries));
    expect(edited.userName, 'Alex');

    final due = DateTime(month.year, month.month, month.day + 2);
    final bill = await alex.addBill(
      BillDraft(title: 'Netflix', amount: 549, category: 'entertainment', frequency: 'monthly', nextDueOn: due),
    );
    expect((await sam.bills()).single.nextDueOn, due);
    final renamed = await sam.updateBill(
      bill.id,
      BillDraft(title: 'Netflix 4K', amount: 549, category: 'entertainment', frequency: 'monthly', nextDueOn: due),
    );
    expect(renamed.title, 'Netflix 4K');
    expect((await alex.dashboard()).upcomingBills.single.title, 'Netflix 4K');
    // Pay, undo, then pay for real.
    final undone = await sam.payBill(bill.id);
    final restored = await alex.unpayBill(bill.id, transactionId: undone.transactionId, previousDue: due);
    expect(restored.nextDueOn, due);
    expect((await alex.transactions(month: month)).where((t) => t.id == undone.transactionId), isEmpty);
    final paid = (await sam.payBill(bill.id)).bill;
    expect(paid.nextDueOn.isAfter(due), isTrue);
    expect((await alex.transactions(month: month)).where((t) => t.title == 'Netflix 4K'), hasLength(1));
    await alex.deleteBill(bill.id);
    expect(await sam.bills(), isEmpty);
    final netflix = (await alex.transactions(month: month)).firstWhere((t) => t.title == 'Netflix 4K');
    await alex.deleteTransaction(netflix.id);

    final pizza = await alex.addTransaction(
      TxnDraft(
        type: 'expense',
        amount: 900,
        category: 'food',
        title: 'Pizza',
        paymentMethod: 'cash',
        isSplit: true,
        occurredOn: month,
        paidBy: joined.user.id,
      ),
    );
    expect(pizza.userName, 'Sam');
    // Alex's groceries (1,250) vs Sam's pizza (900): Sam owes half the difference.
    final owed = await alex.balance();
    expect([owed.owes!.from.name, owed.owes!.amount], ['Sam', 175]);
    final settlement = await sam.settleUp(amount: 175, fromUserId: joined.user.id);
    expect((await alex.balance()).owes, isNull);
    await alex.deleteSettlement(settlement.id);
    expect((await sam.balance()).owes!.amount, 175);
    await alex.deleteTransaction(pizza.id);

    final dash = await sam.dashboard();
    expect(dash.budget.spent, 1250);
    expect(dash.spending['food'], 1250);
    expect((await sam.feed()).single.subtitle, 'Groceries');
    expect(dash.budget.lines.single.remaining, 3750);
    expect(dash.recent.single.userName, 'Alex');

    final goal = await alex.addGoal(name: 'Japan Trip', icon: 'travel', target: 80000, targetDate: DateTime(month.year + 1));
    final spentBefore = (await alex.dashboard()).budget.spent;
    final after = await sam.contribute(goal.id, 8000);
    expect(after.goal.saved, 8000);
    final transfer = (await alex.transactions(month: month)).firstWhere((t) => t.id == after.transferId);
    expect([transfer.isTransfer, transfer.goalId, transfer.title], [true, goal.id, 'Transfer to Japan Trip']);
    final saved = await alex.dashboard();
    expect([saved.budget.spent, saved.savedThisMonth], [spentBefore, 8000]);
    await alex.deleteTransaction(after.transferId!);
    expect((await alex.goals()).single.saved, 0);
    await sam.contribute(goal.id, 8000);

    // Cancel releases the savings; restore takes the release back.
    final cancelled = await alex.cancelGoal(goal.id);
    expect([cancelled.cancelled, cancelled.saved], [true, 8000]);
    expect((await sam.transactions(month: month)).where((t) => t.isRelease && t.amount == 8000), hasLength(1));
    expect((await alex.restoreGoal(goal.id)).cancelled, isFalse);
    expect((await sam.transactions(month: month)).where((t) => t.isRelease), isEmpty);
    expect((await alex.goals()).single.contributorIds, isNotEmpty);

    await sam.addMood(mood: 'tired', note: 'just me', isPrivate: true);
    await sam.addMood(mood: 'happy', isPrivate: false);
    expect((await alex.moods()).map((m) => m.mood), ['happy']);

    final talk = await sam.answerTalk('A trip together');
    expect(talk.answered, isTrue);
    expect((await alex.currentTalk()).answers, isEmpty);

    final when = DateTime(month.year, month.month, month.day + 3, 19);
    final plan = await alex.addPlan(kind: 'date', title: 'Date Night', scheduledAt: when);
    expect(plan.scheduledAt, when);
    expect((await sam.plans()).single.title, 'Date Night');

    await alex.updateTheme('peach');
    expect((await sam.restoreSession())?.couple?.theme, 'peach');

    // Picked goals become starter goals, and the budget is set up.
    final robin = ApiRepository(apiUrl);
    await robin.start(
      'Robin',
      const OnboardingProfile(financialGoals: ['emergency', 'travel'], familyGoals: ['kids'], monthlyBudget: 25000),
    );
    await robin.createNest('sage');
    expect((await robin.goals()).map((g) => g.name), unorderedEquals(['Emergency Fund', 'Travel Fund', 'Baby Fund']));
    expect((await robin.budget(month)).total, 25000);

    // Profile photos: the partner sees a re-encoded JPEG; anyone else gets nothing.
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAE0lEQVR4nGMM6ElhgAEmOAsvBwA/cAFIjcJkMQAAAABJRU5ErkJggg==');
    final withPhoto = await alex.uploadAvatar(png, 'me.png');
    expect(withPhoto.user.avatarVersion, isNotNull);
    final seen = await sam.avatar(withPhoto.user.id);
    expect(seen!.sublist(0, 2), [0xFF, 0xD8], reason: 'served as JPEG');
    expect(await robin.avatar(withPhoto.user.id), isNull);
    expect((await alex.removeAvatar()).user.avatarVersion, isNull);
    expect(await sam.avatar(withPhoto.user.id), isNull);

    // Activity loads the whole month (no 30-item cut-off) and custom ranges.
    final day = DateTime(month.year, month.month, 1);
    for (var i = 0; i < 31; i++) {
      await robin.addTransaction(
        TxnDraft(type: 'expense', amount: 10, category: 'food', title: 'Coffee $i', paymentMethod: 'cash', isSplit: false, occurredOn: day),
      );
    }
    final lastMonth = DateTime(month.year, month.month - 1, 20);
    await robin.addTransaction(
      TxnDraft(
        type: 'expense',
        amount: 99,
        category: 'food',
        title: 'Old dinner',
        paymentMethod: 'cash',
        isSplit: false,
        occurredOn: lastMonth,
      ),
    );
    expect((await robin.transactions(month: month)).where((t) => t.title.startsWith('Coffee')), hasLength(31));
    final ranged = await robin.transactions(from: DateTime(month.year, month.month - 1, 1), to: day);
    expect(ranged.map((t) => t.title), contains('Old dinner'));
    expect(ranged, hasLength(32));

    // Alex loses their phone: Sam re-links them, and the old phone is signed out.
    final relink = await sam.relinkCode();
    expect(relink.forName, 'Alex');
    final alexNewPhone = ApiRepository(apiUrl);
    expect((await alexNewPhone.redeemRelink(relink.code)).user.name, 'Alex');
    await expectLater(alex.dashboard(), throwsA(anything));
    await expectLater(ApiRepository(apiUrl).redeemRelink(relink.code), throwsA(anything));

    // The recovery key works too, and signs out the phone before it.
    final alexThirdPhone = ApiRepository(apiUrl);
    expect((await alexThirdPhone.recover(a.recoveryKey)).couple!.inviteCode, nest.couple!.inviteCode);
    await expectLater(alexNewPhone.dashboard(), throwsA(anything));
    expect((await alexThirdPhone.dashboard()).budget.total, 20000);
  }, skip: apiUrl.isEmpty ? 'Set --dart-define=API_URL to run against a live backend' : null);
}
