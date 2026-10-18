import '../../data/models.dart';

enum TxnKind { expense, income, savings }

enum Payer { anyone, me, partner }

enum SplitFilter { any, shared, personal }

/// Which transactions Activity shows. Everything empty or "any" shows all.
class TxnFilter {
  const TxnFilter({
    this.kinds = const {},
    this.categories = const {},
    this.payer = Payer.anyone,
    this.split = SplitFilter.any,
    this.wallets = const {},
  });

  static const none = TxnFilter();

  /// Expenses, income and/or savings (transfers into and releases from goals).
  final Set<TxnKind> kinds;

  /// Expense category keys.
  final Set<String> categories;
  final Payer payer;
  final SplitFilter split;

  /// Wallet ids: money paid from, received into or moved through any of them.
  final Set<int> wallets;

  int get activeCount =>
      (kinds.isEmpty ? 0 : 1) +
      (categories.isEmpty ? 0 : 1) +
      (payer == Payer.anyone ? 0 : 1) +
      (split == SplitFilter.any ? 0 : 1) +
      (wallets.isEmpty ? 0 : 1);

  bool get isActive => activeCount > 0;

  bool matches(Txn t, int meId) {
    final kind = t.isExpense
        ? TxnKind.expense
        : t.isIncome
        ? TxnKind.income
        : TxnKind.savings;
    if (kinds.isNotEmpty && !kinds.contains(kind)) return false;
    if (categories.isNotEmpty && !categories.contains(t.category)) return false;
    if (payer == Payer.me && t.userId != meId) return false;
    if (payer == Payer.partner && t.userId == meId) return false;
    if (split == SplitFilter.shared && !t.isSplit) return false;
    if (split == SplitFilter.personal && t.isSplit) return false;
    if (wallets.isNotEmpty && !wallets.contains(t.walletId) && !wallets.contains(t.toWalletId)) return false;
    return true;
  }

  List<Txn> apply(List<Txn> txns, int meId) => isActive
      ? [
          for (final t in txns)
            if (matches(t, meId)) t,
        ]
      : txns;

  TxnFilter copyWith({Set<TxnKind>? kinds, Set<String>? categories, Payer? payer, SplitFilter? split, Set<int>? wallets}) => TxnFilter(
    kinds: kinds ?? this.kinds,
    categories: categories ?? this.categories,
    payer: payer ?? this.payer,
    split: split ?? this.split,
    wallets: wallets ?? this.wallets,
  );
}
