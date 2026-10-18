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

    // Paydays: logged as income with the real amount, undoable, and only by their owner.
    final salary = await alex.addPayday(const PaydayDraft(amount: 22500, frequency: 'semimonthly', days: [30, 15]));
    expect(salary.days, [15, 30]);
    expect(salary.scheduleLabel, '15th & 30th');
    final weekly = await alex.addPayday(PaydayDraft(title: 'Tips', amount: 900, frequency: 'weekly', nextOn: month));
    expect(weekly.days, isEmpty);
    expect((await sam.dashboard()).paydays.map((d) => d.title), containsAll(['Salary', 'Tips']));
    await expectLater(sam.receivePayday(salary.id), throwsA(anything));
    final got = await alex.receivePayday(salary.id, amount: 23100);
    expect(got.payday.nextOn.isAfter(salary.nextOn), isTrue);
    expect((await alex.transactions(month: month)).where((t) => t.isIncome && t.amount == 23100), hasLength(1));
    final back = await alex.unreceivePayday(salary.id, transactionId: got.transactionId, previousNext: salary.nextOn);
    expect(back.nextOn, salary.nextOn);
    expect((await alex.updatePayday(weekly.id, const PaydayDraft(title: 'Tips', amount: 1000, frequency: 'monthly', days: [5]))).days, [5]);
    await alex.deletePayday(weekly.id);
    expect((await sam.paydays()).map((d) => d.title), ['Salary']);

    // Wallets: balances follow what's logged; a partner's stay private.
    final gcash = await alex.addWallet(const WalletDraft(name: 'GCash', kind: 'ewallet', provider: 'gcash', balance: 5000));
    expect(gcash.balance, 5000);
    final ours = await alex.addWallet(const WalletDraft(name: 'Our Maya', kind: 'ewallet', provider: 'maya', isShared: true));
    expect(ours.isShared, isTrue);
    final card = await alex.addWallet(const WalletDraft(name: 'BPI', kind: 'credit', provider: 'bpi', last4: '4821'));
    final spent = await alex.addTransaction(
      TxnDraft(
        type: 'expense',
        amount: 1200,
        category: 'food',
        title: 'Lunch',
        paymentMethod: 'cash',
        isSplit: false,
        occurredOn: month,
        walletId: card.id,
      ),
    );
    expect(spent.walletId, card.id);
    expect(spent.paymentMethod, 'card');
    final mine = await alex.wallets();
    expect(mine.first.name, 'Our Maya');
    expect(mine.firstWhere((w) => w.id == card.id).balance, -1200);
    expect((await alex.setWalletBalance(gcash.id, 4100)).balance, 4100);
    final seenBySam = await sam.wallets();
    expect(seenBySam.firstWhere((w) => w.id == gcash.id).balance, isNull);
    expect(seenBySam.firstWhere((w) => w.id == ours.id).balance, 0);
    // Three added, plus each partner's built-in Cash.
    expect((await sam.dashboard()).wallets, hasLength(5));
    final alexCash = mine.firstWhere((w) => w.builtin && w.ownerId == gcash.ownerId);
    final samCash = seenBySam.firstWhere((w) => w.builtin && w.ownerId != gcash.ownerId);
    expect(alexCash.isCash, isTrue);
    await expectLater(alex.archiveWallet(alexCash.id), throwsA(anything));
    await alex.updateWallet(gcash.id, const WalletDraft(name: 'GCash', kind: 'ewallet', provider: 'gcash', showBalanceToPartner: true));
    expect((await sam.wallets()).firstWhere((w) => w.id == gcash.id).balance, 4100);
    // Moving money: a top-up into the shared wallet isn't spending, and deleting it undoes it.
    final topUp = await alex.moveMoney(fromWalletId: gcash.id, toWalletId: ours.id, amount: 1000, note: 'My share');
    expect(topUp.transaction.isMove, isTrue);
    expect(topUp.transaction.toWalletId, ours.id);
    expect(topUp.wallets.firstWhere((w) => w.id == ours.id).balance, 1000);
    final split = await sam.balance();
    expect(split.members.firstWhere((m) => m.name == 'Alex').toppedUpThisMonth, 1000);
    await expectLater(sam.moveMoney(fromWalletId: gcash.id, toWalletId: ours.id, amount: 1), throwsA(anything));
    await alex.deleteTransaction(topUp.transaction.id);
    expect((await alex.wallets()).firstWhere((w) => w.id == gcash.id).balance, 4100);
    // A withdrawal with a fee: the fee is spending from the same wallet, and goes with the move.
    final atm = await alex.moveMoney(fromWalletId: gcash.id, toWalletId: alexCash.id, amount: 500, fee: 15);
    expect(atm.wallets.firstWhere((w) => w.id == gcash.id).balance, 4100 - 515);
    final fee = (await alex.transactions(month: DateTime.now())).firstWhere((t) => t.moveId == atm.transaction.id);
    expect(fee.isExpense, isTrue);
    expect(fee.amount, 15);
    await alex.deleteTransaction(atm.transaction.id);
    expect((await alex.transactions(month: DateTime.now())).where((t) => t.moveId == atm.transaction.id), isEmpty);
    // Settling up can come out of one wallet and land in another.
    final paidBack = await sam.settleUp(amount: 50, fromUserId: samCash.ownerId!, fromWalletId: samCash.id, toWalletId: gcash.id);
    expect(paidBack.toWalletName, 'GCash');
    expect((await alex.wallets()).firstWhere((w) => w.id == gcash.id).balance, 4150);
    await expectLater(sam.settleUp(amount: 1, fromUserId: samCash.ownerId!, fromWalletId: gcash.id), throwsA(anything));
    await sam.deleteSettlement(paidBack.id);
    expect((await alex.wallets()).firstWhere((w) => w.id == gcash.id).balance, 4100);
    // Paydays land in a wallet, bills are paid from one, goal savings come from one.
    final pay = await alex.addPayday(PaydayDraft(title: 'Bonus', amount: 900, frequency: 'weekly', nextOn: month, walletId: gcash.id));
    expect(pay.walletId, gcash.id);
    await alex.receivePayday(pay.id);
    final wifi = await alex.addBill(
      BillDraft(title: 'Wifi', amount: 1500, category: 'bills', frequency: 'monthly', nextDueOn: month, walletId: gcash.id),
    );
    expect(wifi.walletId, gcash.id);
    final paidBill = await alex.payBill(wifi.id);
    final savedGoal = (await alex.goals()).first;
    await alex.contribute(savedGoal.id, 100, walletId: gcash.id);
    expect((await alex.wallets()).firstWhere((w) => w.id == gcash.id).balance, 4100 + 900 - 1500 - 100);
    expect((await alex.transactions(month: month)).firstWhere((t) => t.id == paidBill.transactionId).walletId, gcash.id);
    await alex.archiveWallet(card.id);
    expect((await alex.wallets()).map((w) => w.id), isNot(contains(card.id)));

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
