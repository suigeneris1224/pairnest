import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/data/models.dart';
import 'package:pairnest/features/activity/txn_filter.dart';

Txn _t(int id, {String type = 'expense', String category = 'food', int userId = 1, bool split = false}) => Txn(
  id: id,
  userId: userId,
  userName: userId == 1 ? 'Alex' : 'Sam',
  type: type,
  amount: 100,
  category: category,
  title: 'T$id',
  paymentMethod: 'cash',
  isSplit: split,
  occurredOn: DateTime(2028, 3, id),
);

void main() {
  final txns = [
    _t(1, split: true),
    _t(2, category: 'bills', userId: 2, split: true),
    _t(3, type: 'income', category: 'income'),
    _t(4, type: 'transfer', category: 'savings', userId: 2),
    _t(5, type: 'release', category: 'savings'),
  ];
  List<int> ids(TxnFilter f) => [for (final t in f.apply(txns, 1)) t.id];

  test('no filter shows everything', () {
    expect(ids(TxnFilter.none), [1, 2, 3, 4, 5]);
    expect(TxnFilter.none.activeCount, 0);
  });

  test('type: savings covers transfers and releases', () {
    expect(ids(const TxnFilter(kinds: {TxnKind.savings})), [4, 5]);
    expect(ids(const TxnFilter(kinds: {TxnKind.expense, TxnKind.income})), [1, 2, 3]);
  });

  test('category, payer and split combine', () {
    expect(ids(const TxnFilter(categories: {'bills'})), [2]);
    expect(ids(const TxnFilter(payer: Payer.me)), [1, 3, 5]);
    expect(ids(const TxnFilter(payer: Payer.partner)), [2, 4]);
    expect(ids(const TxnFilter(split: SplitFilter.shared)), [1, 2]);
    expect(ids(const TxnFilter(split: SplitFilter.personal, payer: Payer.me)), [3, 5]);
    const all = TxnFilter(kinds: {TxnKind.expense}, categories: {'food'}, payer: Payer.me, split: SplitFilter.shared);
    expect(ids(all), [1]);
    expect(all.activeCount, 4);
  });

  test('wallet: paid from, received into or moved through it', () {
    Txn w(int id, {String type = 'expense', int? wallet, int? to}) => Txn(
      id: id,
      userId: 1,
      userName: 'Alex',
      type: type,
      amount: 100,
      category: 'food',
      title: 'W$id',
      paymentMethod: 'cash',
      isSplit: false,
      occurredOn: DateTime(2028, 3, 1),
      walletId: wallet,
      toWalletId: to,
    );
    final list = [w(1, wallet: 7), w(2, wallet: 8), w(3, type: 'move', wallet: 8, to: 7), w(4)];
    const f = TxnFilter(wallets: {7});
    expect([for (final t in f.apply(list, 1)) t.id], [1, 3]);
    expect(f.activeCount, 1);
    expect(f.copyWith(wallets: {}).isActive, isFalse);
  });
}
