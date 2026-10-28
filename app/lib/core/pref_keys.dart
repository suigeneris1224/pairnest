/// Every SharedPreferences key the app uses, in one place.
abstract final class PrefKeys {
  // This phone's choices; they survive signing out.
  static const onboarded = 'onboarded';
  static const themeChosen = 'theme_chosen';
  static const theme = 'theme';
  static const hideAmounts = 'hide_amounts';

  // The signed-in account's; cleared on sign-out so the next one starts fresh.
  static const feedSeenAt = 'feed_seen_at';
  static const lastWallet = 'last_wallet_id';
  static const lastTransferWallet = 'last_transfer_wallet_id';
  static const lastSettleWallet = 'last_settle_wallet_id';
  static const _recapSeenPrefix = 'recap_seen_';

  static String recapSeen(String month) => '$_recapSeenPrefix$month';

  static bool isAccountKey(String key) =>
      key == feedSeenAt || key == lastWallet || key == lastTransferWallet || key == lastSettleWallet || key.startsWith(_recapSeenPrefix);
}
