import 'dart:typed_data';

import 'models.dart';

/// Everything the app needs from the backend. [MockRepository] serves
/// in-memory demo data; [ApiRepository] talks to the Laravel API.
abstract class PairnestRepository {
  Future<Me?> restoreSession();

  /// Onboarding: creates an anonymous account (no email, no password) and
  /// returns its recovery key, shown to the user once.
  Future<({Me me, String recoveryKey})> start(String name, OnboardingProfile profile);

  /// A new phone gets back in with a recovery key, or a code from the partner.
  Future<Me> recover(String recoveryKey);
  Future<Me> redeemRelink(String code);

  /// On the partner's phone: a one-time code that signs their partner back in.
  Future<({String code, DateTime expiresAt, String forName})> relinkCode();

  /// Issues a new recovery key; the old one stops working.
  Future<String> newRecoveryKey();

  /// "Remove this phone."
  Future<void> logout();

  /// The phones signed in to your account, and signing one of them out.
  Future<List<Device>> devices();
  Future<void> removeDevice(int id);

  /// Your profile photo; only you and your partner can see it.
  Future<Me> uploadAvatar(Uint8List bytes, String filename);
  Future<Me> removeAvatar();

  /// A member's photo, or null if they have none.
  Future<Uint8List?> avatar(int userId);
  Future<Me> createNest(String theme);
  Future<Me> joinNest(String code);
  Future<void> updateTheme(String theme);

  Future<Dashboard> dashboard();

  /// The partner's recent actions, newest first.
  Future<List<FeedItem>> feed();

  /// A month's transactions, or those between [from] and [to] (inclusive).
  Future<List<Txn>> transactions({DateTime? month, DateTime? from, DateTime? to, String query = ''});
  Future<Txn> addTransaction(TxnDraft draft);
  Future<Txn> updateTransaction(int id, TxnDraft draft);
  Future<void> deleteTransaction(int id);

  Future<BudgetSummary> budget(DateTime month);
  Future<BudgetSummary> saveBudget(DateTime month, double total, Map<String, double> limits);

  Future<List<Goal>> goals();
  Future<Goal> addGoal({required String name, String? subtitle, required String icon, required double target, DateTime? targetDate});

  /// Moves money into a goal. [transferId] is the Activity entry it logs;
  /// deleting that transaction undoes the transfer.
  Future<Goal> updateGoal(
    int id, {
    required String name,
    String? subtitle,
    required String icon,
    required double target,
    DateTime? targetDate,
  });

  /// Cancels a goal: it stays in history and its savings are released.
  Future<Goal> cancelGoal(int id);

  /// Brings a cancelled goal back, with its savings set aside again.
  Future<Goal> restoreGoal(int id);

  Future<({Goal goal, int? transferId})> contribute(int goalId, double amount, {int? walletId});

  Future<List<Mood>> moods();
  Future<Mood> addMood({required String mood, String? note, required bool isPrivate});

  Future<TalkState> currentTalk();
  Future<TalkState> answerTalk(String answer);
  Future<List<PastTalk>> talkHistory();

  Future<List<Bill>> bills();
  Future<Bill> addBill(BillDraft draft);
  Future<Bill> updateBill(int id, BillDraft draft);
  Future<void> deleteBill(int id);

  /// Logs this period's payment as an expense and returns the bill with its
  /// next due date.
  Future<({Bill bill, int transactionId})> payBill(int id);

  /// Undoes [payBill]: deletes its expense and puts the due date back.
  Future<Bill> unpayBill(int id, {required int transactionId, required DateTime previousDue});

  Future<List<Wallet>> wallets();
  Future<Wallet> addWallet(WalletDraft draft);
  Future<Wallet> updateWallet(int id, WalletDraft draft);

  /// Deletes an unused wallet, or archives one that has transactions.
  Future<void> archiveWallet(int id);

  /// Sets what the wallet holds right now.
  Future<Wallet> setWalletBalance(int id, double balance);

  /// Moves money between two of your (or shared) wallets: not spending.
  /// A [fee] is logged as an expense from the same wallet. Deleting the
  /// returned transaction undoes both.
  Future<({Txn transaction, List<Wallet> wallets})> moveMoney({
    required int fromWalletId,
    required int toWalletId,
    required double amount,
    String? note,
    double? fee,
  });

  Future<List<Payday>> paydays();
  Future<Payday> addPayday(PaydayDraft draft);
  Future<Payday> updatePayday(int id, PaydayDraft draft);
  Future<void> deletePayday(int id);

  /// Logs this payday's pay as income ([amount] when it differs from the
  /// plan) and returns the payday moved on to the next one.
  Future<({Payday payday, int transactionId})> receivePayday(int id, {double? amount});

  /// Undoes [receivePayday]: deletes its income and puts the payday back.
  Future<Payday> unreceivePayday(int id, {required int transactionId, required DateTime previousNext});

  /// Who owes whom between the two of you, as a running total.
  Future<SplitBalance> balance();

  /// Records a payback; the wallets (the payer's own, the receiver's own) are optional.
  Future<Settlement> settleUp({required double amount, required int fromUserId, int? fromWalletId, int? toWalletId});
  Future<void> deleteSettlement(int id);

  /// Sets which of your own wallets your side of a settle-up went through.
  Future<Settlement> setSettlementWallet(int id, int? walletId);

  Future<List<Plan>> plans();
  Future<Plan> addPlan({required String kind, required String title, String? notes, DateTime? scheduledAt, int? goalId});
  Future<void> deletePlan(int id);
}
